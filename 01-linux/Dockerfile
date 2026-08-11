FROM bstar999/linux-lab-image:systemd

# Copy the script into the image
COPY script.sh /script.sh
 
# Owned by root, no execute permission (owner: rw, group: r, others: r)
RUN chown root:root /script.sh && \
    chmod 644 /script.sh
 
# Pre-create the file the script writes to, owned by root,
# with no read/write permissions for "others"
# (owner: rw, group: rw, others: none)
RUN touch /root/file.txt && \
    chown root:root /root/file.txt && \
    chmod 660 /root/file.txt
 
CMD ["/sbin/init"]
 


