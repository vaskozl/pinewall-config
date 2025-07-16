# Define variables
HOSTNAME = pinewall
IMAGE_FILE = alpine-rpi-edge-aarch64.img.gz
DEVICE = /dev/disk6

# Build target
.PHONY: build
build:
	docker build --progress=plain --no-cache -t $(HOSTNAME) .
	docker create --name $(HOSTNAME) $(HOSTNAME)
	docker cp $(HOSTNAME):/tmp/images/. .
	docker rm $(HOSTNAME)

# Flash target
.PHONY: flash
flash:
	sudo diskutil unmountDisk $(DEVICE)
	gunzip -c $(IMAGE_FILE) | sudo dd of=$(DEVICE) bs=1m status=progress conv=fsync oflag=sync

.PHONY: liveflash
liveflash:
	cat $(IMAGE_FILE) | ssh pinewall 'gunzip -c | sudo dd of=/dev/mmcblk0 bs=1048576 conv=fsync'

# Clean target
.PHONY: clean
clean:
	rm -f $(IMAGE_FILE)
	-docker rm $(HOSTNAME) 2> /dev/null || true

# Sync target
.PHONY: sync
sync:
	$(eval FILES := $(shell find config -type f))
	@for file in $(FILES); do \
		if [ "$$file" != "config/etc/wireguard/wg0.conf" ]; then \
			scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r $(HOSTNAME):$${file#config} ./$$file; \
		fi; \
	done
