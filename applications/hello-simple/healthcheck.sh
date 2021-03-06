#!/bin/bash
echo "Script started"

if [ -z "$PUBLIC_ADDRESS" ]
then
  GET_SERVICE_ENDPOINT=$(curl --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" https://kubernetes.default.svc.cluster.local/api/v1/namespaces/promotions-manager/services/ 2>/dev/null | grep -o 'hostname.*' | cut -f2- -d: | tr -d '"' | tr -d ' ')
  PUBLIC_ENDPOINT="http://${GET_SERVICE_ENDPOINT}"
else
  PUBLIC_ENDPOINT="http://${PUBLIC_ADDRESS}"
fi

TEXT_TO_CHECK='My Private IP is'

# Create retry function
function retry {
  while :
  do
    STATUSCODE=$(curl -L -o /dev/null -s -w "%{http_code}\n" -k "${@}")
    if [[ "$STATUSCODE" -ne "000" && "$STATUSCODE" -eq "200" ]] 
    then
      sleep 5
      RESPONSE=$(curl -L -k -s "${@}")
      echo "The response was: ${RESPONSE}"
      if [[ "$RESPONSE" == *"$TEXT_TO_CHECK"* ]]
      then
        echo "External ALB ${@} is healthy and has valid text. Statuscode: ${STATUSCODE}" && break
      fi
        echo "External ALB ${@} is healthy but has invalid text. Statuscode: ${STATUSCODE}" && exit 1
    fi
      echo "External ALB ${@} is unhealthy. Statuscode: ${STATUSCODE}" && sleep 20
  done
}


for ALB in $PUBLIC_ENDPOINT;
do
  retry $ALB
done

