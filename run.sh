#!/bin/sh
# Run localhost proxies direct to Kubernetes services
#
# usage: ./run.sh
#
# variables:
# - ALLOW_LIST: space separated list of services that can be started, empty string means all can (default: "")

ALLOW_LIST="${ALLOW_LIST:-}"

function get_ideal_state() {
  # Configuration for Kubernetes API access
  APISERVER=https://kubernetes.default.svc
  SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount
  NAMESPACE=$(cat ${SERVICEACCOUNT}/namespace)
  TOKEN=$(cat ${SERVICEACCOUNT}/token)
  CACERT=${SERVICEACCOUNT}/ca.crt

  curl -s --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/namespaces/${NAMESPACE}/services \
    | jq -r '.items[] | .metadata["name"] as $serviceName | .spec["type"] as $type | .spec["ports"][] | {name: $serviceName, type: $type, port: .port, protocol: .protocol} | select(.protocol == "TCP" and .type == "ClusterIP") | "\(.name),\(.port)"'
}

function get_actual_state() {
  ps aux -o args | grep -e '^redir ' | rev | cut -d' ' -f1,2 | rev | sed 's/ /,/'
}

function start_proxy() {
  # usage: start_proxy SERVICE_NAME SERVICE_PORT
  name="$1"
  port="$2"

  # start proxy in the background
  redir localhost:$port $name:$port
}

function stop_proxy() {
  # usage: stop_proxy SERVICE_NAME SERVICE_PORT
  name="$1"
  port="$2"

  # stop proxy running in background
  # xargs trims whitespace
  pid=$(ps aux -o pid,args | grep -e $name' '$port'$' | xargs | cut -d' ' -f1)
  kill -9 $pid
}

while true; do
  # fetch current states of the world
  actual_state=$(get_actual_state)
  ideal_state=$(get_ideal_state)

  # reconcile states
  for serviceLine in $ideal_state
  do
    # TODO: replace string contains with stricter array contains
    if [[ "${actual_state}" != *"${serviceLine}"* ]]; then
      name=$(echo $serviceLine | cut -d',' -f1)
      port=$(echo $serviceLine | cut -d',' -f2)
      # TODO: replace string contains with stricter array contains
      if [[ "${ALLOW_LIST}" != "" && "${ALLOW_LIST}" == *"${name}"* ]]; then
        echo "${serviceLine} should be running, starting..."
        start_proxy $name $port
      fi
    fi
  done

  for serviceLine in $actual_state
  do
    # TODO: replace string contains with stricter array contains
    if [[ "${ideal_state}" != *"${serviceLine}"* ]]; then
      echo "${serviceLine} should not be running, terminating..."
      name=$(echo $serviceLine | cut -d',' -f1)
      port=$(echo $serviceLine | cut -d',' -f2)
      stop_proxy "${name}" "${port}"
    fi
  done

  # check again soon
  sleep 5
done
