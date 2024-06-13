# Use an appropriate base image
FROM amazonlinux:2

# Install required packages
RUN yum install -y \
    aws-cli \
    jq \
    && yum clean all

# Set locale for UTF-8 encoding
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8

# Copy the bash script into the container
COPY notification.sh /usr/local/bin/notification.sh

# Make the script executable
RUN chmod +x /usr/local/bin/notification.sh

# Run the bash script
ENTRYPOINT ["/usr/local/bin/notification.sh"]
