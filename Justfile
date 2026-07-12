# ── Chaossynergy — CentOS Stream 10 (Bluefin LTS base) ────────────
# Agent-native immutable Linux. The OS is the agent interface.

# Build the container image
build-chaossynergy tag="stable":
    #!/usr/bin/bash
    set -eoux pipefail
    sudo podman build \
        --build-arg BASE_TAG="{{ tag }}" \
        -t localhost/chaossynergy:{{ tag }} \
        -f Containerfile .

# Build a QCOW2 VM disk image
build-qcow2 tag="stable":
    #!/usr/bin/bash
    set -eoux pipefail
    sudo rm -rf output/qcow2
    mkdir -p output/qcow2
    sudo podman run --rm -it \
        --privileged \
        --pull=newer \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        -v /var/home/panos/workspace/chaossynergy/output/qcow2:/output \
        quay.io/centos-bootc/bootc-image-builder:latest \
        --type qcow2 \
        localhost/chaossynergy:{{ tag }}
    sudo chown -R $USER:$USER output/qcow2

# Run the QEMU VM
run-vm-qcow2 tag="stable":
    #!/usr/bin/bash
    set -eoux pipefail
    DISK=$(ls output/qcow2/qcow2/*.qcow2 2>/dev/null | head -1)
    if [ -z "$DISK" ]; then
        echo "No QCOW2 found. Run: just build-qcow2"
        exit 1
    fi
    qemu-system-x86_64 \
        -enable-kvm \
        -m 8192 \
        -cpu host \
        -smp 4 \
        -drive file="$DISK",if=virtio,format=qcow2 \
        -netdev user,id=net0,hostfwd=tcp::8006-:80 \
        -device virtio-net-pci,netdev=net0 \
        -display gtk,gl=on \
        -vga virtio

# ── Bluefin upstream build system (kept for reference) ────────────
# The original Bluefin Justfile from the fork is at .github/bluefin-justfile.bak

check:
    @echo "OK"
# We don't use their build pipeline anymore — we build FROM their LTS image.
# To rebase on upstream changes, merge ublue-os/bluefin main into chaos-f44
# and port any relevant changes to our Containerfile.