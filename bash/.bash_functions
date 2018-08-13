#!/bin/bash
timestamp() {
  date +"%F %T"
}

function testsites {
  file=$1
  log=$2
  declare -a errors  
  if [[ -e $file ]]  
  then
    #while IFS=$'\n' read -r line; do
    echo $(timestamp) Starting site check
    while read -r line
    do
      #echo Testing $line
      code=$(curl $line --http1.1 -s -o /dev/null -w %{http_code})
      case $code in
        20*)
          shift
          ;;
        40*)
          echo "$(timestamp):ERROR:$code:$line" | tee -a ~/logfiles/$(date +%F)-$log.log
          errors+=("$(timestamp):ERROR:$code:$line ")
          shift
          ;;
        50*)
          echo "$(timestamp):ERROR:$code:$line:Proxy" | tee -a ~/logfiles/$(date +%F)-$log.log
          errors+=("$(timestamp):ERROR:$code:$line:Proxy issue ")          
          shift
          ;;
        *)
          echo "$(timestamp):ERROR:$code:$line:Somethign else is wrong " | tee -a ~/logfiles/$(date +%F)-$log.log
          errors+=("$(timestamp):ERROR:$code:$line:Somethign else is wrong ")
          shift
          ;;
      esac
    done < $file
  else
    echo $file does not exist
  fi
  #echo ${errors[@]}
  printf '%s\n' "${errors[@]}"
  echo "$(timestamp) Finished site check"
}
function GET-EC2-USAGE(){
  if [[ $# -le 0 ]]; then
    echo -e "$1 is not a valid option\n"
  fi
cat <<-EOF
  get-ec2 - Get ec2 machines based off the tag names (owner and name) and get back their private ip, name and status   

     Options
       -o, --owner - owner of the ec2 machines
       -e, --env - name of the env of the machines
       -p, --profile - aws profile to use
       -ip_only - get only ip address back
       -h, --help

     ex.
       get-ec2 -o SI -e SHARED-DEV -p NonProd -ip_only
EOF
}

function get-ec2(){
  owner=""
  env=""
  profile=""
  ip_only=false
  if [ "$#" -le 1 ]
    then
      GET-EC2-USAGE $1
      return 1
  fi
    while [ "$#" -gt 0 ]
    do
      key="$1"
      value="$2"
#      echo key is $key
#      echo value is $value
      case "$key" in
        -h|--help)
          SET-DOCKER-USAGE
          return 8
          ;;
        -o|--owner)
          owner="$value"
          shift
          shift
          ;;
        -e|--env)
          env="$value"
          shift
          shift
          ;;
        -p|--profile)
          profile="$value"
          shift
          shift
          ;;
        -ip_only)
          ip_only=true
          shift;
          ;;
        *)
          GET-EC2-USAGE $2
          return 4
          ;;
      esac
    done
  # check for null owner, needed arg
  if [[ -z "$owner" ]]; then
    echo "No Arguments provided. ex. get_ec2 VMS DEV"
    return
  fi

  # set profile if none provided to default  
  if [[ -z "$profile" ]]; then
     profile="default"
  fi
  output=''
  # specify if we want all machines we own or just a partiular env
  filter='.Reservations[].Instances[] | [.PrivateIpAddress, .State.Name, (.Tags[]|select(.Key=="Name")|.Value)]'
  if [[ $ip_only ]]; then
    filter='.Reservations[].Instances[] | .PrivateIpAddress'
  fi
  if [[ -z "$env" ]]; then
    aws ec2 describe-instances \
      --profile $profile \
      --filters Name=tag:Owner,Values="$owner" \
      | jq "$filter" -c \
      | sort -V 
  else
     aws ec2 describe-instances --profile $profile --filters Name=tag:Owner,Values="$owner",Name=tag:Name,Values=*$env* | jq -r "$filter" -c | sort -V 
   fi
}

function get-awstoken {
  code=$2
  profile=$1
  region=""
  sn=""
  mfaprofile=""
  echo getting the right arn
  if [ $profile == "prodeu" ]
  then
    mfaprofile="ProdEUMFA"
    region="eu-central-1"
    sn="arn:aws:iam::862092865200:mfa/ben.grisafi"
  elif [ $profile == "prodca" ]
  then
    mfaprofile="ProdCAMFA"
    region="ca-central-1"
    sn="arn:aws:iam::706300911483:mfa/ben.grisafi"
  else
    echo profile is $profile
    mfaprofile="ProdMFA"
    region="us-west-2"
    sn="arn:aws:iam::691696273015:mfa/ben.grisafi"
  fi
  echo $profile sn=$sn
  $(aws sts get-session-token --profile $mfaprofile --region $region --serial-number $sn --token-code $code > tmp.txt)
  cat tmp.txt 
  accesskey=$(python ~/parse_json.py -i tmp.txt -o AccessKeyId)
  echo "Got accesskey - $accesskey"
  secretkey=$(python ~/parse_json.py -i tmp.txt -o SecretAccessKey)
  echo " Got secretkey - $secretkey"
  token=$(python ~/parse_json.py -i tmp.txt -o SessionToken)
  echo " Got token -$token"
  echo "starting substitution"
  sed -i "/\[$profile\]/!b;n;N;N;caws_access_key_id = ${accesskey}\naws_secret_access_key = ${secretkey}\naws_session_token = ${token}" /mnt/c/Users/ben.grisafi/.aws/credentials
  sed -i "/\[$profile\]/!b;n;N;N;caws_access_key_id = ${accesskey}\naws_secret_access_key = ${secretkey}\naws_session_token = ${token}" ~/.aws/credentials
  echo "finished subbing"
  #sed -i '/\[Prod]/q' ~/.aws/credentials
  #echo "aws_access_key_id = ${accesskey}" >> ~/.aws/credentials
  #echo "aws_secret_access_key = ${secretkey}" >> ~/.aws/credentials
  #echo "aws_session_token = ${token}" >> ~/.aws/credentials

}

SET-DOCKER-USAGE ()  { 
  if [[ $# -le 0 ]]; then
    echo -e "$1 is not a valid option\n"
  fi
  cat <<-EOF
    set-docker - sets the docker host variable to one of the manager nodes in that aws environment
   
    set-docker [options] [swarm]
    
    Options
      -s, --swarm
      -h, --help
  
    ex.
      set-docker -s dev"
  
EOF

}

function set-docker {
  if [ "$#" -le 1 ]
  then
    SET-DOCKER-USAGE $1
    return 1
  fi
  while [ "$#" -gt 0 ]
  do
    key="$1"
    value="$2"
    echo key is $key
    echo value is $value
    case "$key" in 
      -h|--help)
        SET-DOCKER-USAGE 
        return 8
        ;;
      -s|--swarm)
        env="$value"
        shift
        shift
        ;;
      *)
        SET-DOCKER-USAGE $2
        return 4
        ;;
    esac
  done
  echo $env is the place
  if [[ -n "$env" ]]; then
    echo "Docker env=$env"
    currentdir=$(pwd)
    cd /mnt/c/Users/ben.grisafi/Source/terraswarm
    echo changed dir
    if [ "$env" == "prod-us" ] || [ "$env" == "prod-eu" ]
    then
      echo we are prod baby
      echo backend-$env.tfvars
      terraform workspace select default
      #rm  -r /mnt/c/Users/ben.grisafi/Source/terraswarm/.terraform
      terraform init -backend-config=backend-$env.tfvars
      terraform workspace select ${env}
    else
      if [[ -d "/.terraform" ]]
      then
        terraform workspace select default
        #rm  -r /mnt/c/Users/ben.grisafi/Source/terraswarm/.terraform
        terraform init -backend-config=backend-nonprod.tfvars
        terraform workspace select ${env}
      else
        terraform workspace select $env
      fi
    fi
    echo selected workspace
    command=$(terraform output managers)
    host="${command##ssh ubuntu@}"
    echo "dns is $host"
    case $env in
      shared-dev)
        export DOCKER_HOST="tcp://$host:2370"
        cd $currentdir
        return 0
        ;;
      shared-qa)
        export DOCKER_HOST="tcp://$host:2370"
        cd $currentdir
        return 0
        ;;
      shared-stg)
        export DOCKER_HOST="tcp://$host:2370"
        cd $currentdir
        return 0
        ;;
      prod-us)
        export DOCKER_HOST="tcp://$host:2370"
        cd $currentdir
        return 0
        ;;
      prod-eu)
        export DOCKER_HOST="tcp://$host:2370"
        cd $currentdir
        return 0
        ;;
      *)
        SET-DOCKER-USAGE $env
        return 1 
        ;;
    esac
  fi
}

