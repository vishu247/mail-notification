#!/bin/bash

export AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$SECRET_KEY_ID
aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
aws configure set region "$AWS_REGION"

# Get instance information
instance_info=$(aws ec2 describe-instances --region ${AWS_REGION} --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`owner`].Value]' --output json)
echo $instance_info

# Parse instance information
instance_ids=($(echo "$instance_info" | jq -r '.[][][0]'))
instance_states=($(echo "$instance_info" | jq -r '.[][][1]'))
owner_emails=($(echo "$instance_info" | jq -r '.[][][2][0]'))

# Loop through instance information
for ((i=0; i<${#instance_ids[@]}; i++)); do
    echo "============================================"
    instance_id="${instance_ids[i]}"
    instance_state="${instance_states[i]}"
    owner_email="${owner_emails[i]}"
    echo "Instance ID: $instance_id"
    echo "Instance State: $instance_state"
    echo "Owner Email: $owner_email"

    if [ "$instance_state" == "running" ]; then
        # HTML content for the email
        HTML_CONTENT=$(cat <<EOF
<!DOCTYPE html>
<html>
<head>
    <style>
        .button {
            display: inline-block;
            padding: 10px 20px;
            font-size: 14px;
            cursor: pointer;
            text-align: center;
            text-decoration: none;
            outline: none;
            color: #fff;
            background-color: #FFD700; /* Yellow color */
            border: none;
            border-radius: 15px;
            box-shadow: 0 9px #999;
        }
        .button:hover {background-color: #FFCC00} /* Darker yellow on hover */
        .button:active {
            background-color: #FFCC00;
            box-shadow: 0 5px #666;
            transform: translateY(4px);
        }
    </style>
</head>
<body>
    <h2>Your virtual machine in AWS QA Labs will automatically shut down</h2>
    <p>Virtual machine with Instance ID <strong>$instance_id</strong> is scheduled to shut down in 2 hours. You may skip this instance shutdown by clicking on the below button:</p>
    <p>
        <a href="$LambdaFunctionUrl?instanceId=$instance_id" class="button">Skip Instance Shutdown ></a>
    </p>
    <p>Note that if you skip the shutdown, a new notification will be sent 2 hours prior to the new shutdown time.</p>
</body>
</html>
EOF
        )

        # Get the tag information provisioned-by: 
        provisioned_by=$(aws ec2 describe-instances --region ${AWS_REGION}  --instance-ids ${instance_id} --query 'Reservations[*].Instances[*].Tags[?Key==`provisioned-by`].Value' --output text)
        
        # Set AWS SES environment variables
        export AWS_ACCESS_KEY_ID=${AWS_MAIL_ACCESS_KEY_ID}
        export AWS_SECRET_ACCESS_KEY=${AWS_MAIL_SECRET_ACCESS_KEY}

        if [ "${provisioned_by}" == "script" ]; then
            # Send email using AWS SES
            vm_name=$(echo "$owner_email" | tr "@" "-")
            aws ses send-email \
            --region "$AWS_REGION_MAIL" \
            --from "$SENDER" \
            --destination "ToAddresses=$owner_email" \
            --message "Subject={Data=Alert—Auto-shutdown of virtual machine $vm_name in 2 hours,Charset=utf-8},Body={Html={Data='$HTML_CONTENT',Charset=utf-8}}"
        else
            echo "Instance $instance_id: Tag 'provisioned_by' is not 'script'. Skipping email notification."
        fi

        # Unset AWS SES environment variables. 
        unset AWS_ACCESS_KEY_ID
        unset AWS_SECRET_ACCESS_KEY
    else
        echo "Instance $instance_id is not in a running state. Skipping email notification."
    fi
done
