# Use an appropriate base image
FROM amazonlinux:2

# Install required packages
RUN yum install -y \
    aws-cli \
    jq \
    && yum clean all

# Copy the bash script into the container
COPY notification.sh /usr/local/bin/notification.sh

# Make the script executable
RUN chmod +x /usr/local/bin/notification.sh

# Run the bash script
ENTRYPOINT ["/usr/local/bin/notification.sh"]
