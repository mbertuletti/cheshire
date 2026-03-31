# Cheshire — How to Build

## 1. Build e avvio Docker

```bash
sudo docker build --platform linux/amd64 --network=host -t cheshire -f .github/Dockerfile .
```

```bash
sudo docker run -it --rm --network=host \
  -v $(pwd):/workspace \
  -v ~/.ssh/id_ed25519:/root/.ssh/id_ed25519:ro \
  -w /workspace cheshire bash
```

---

## 2. Setup Git nel container

```bash
git config --global url."git@github.com:".insteadOf "https://github.com/"
mkdir -p /root/.ssh_local && ssh-keyscan github.com >> /root/.ssh_local/known_hosts
git config --global core.sshCommand "ssh -F /dev/null -o UserKnownHostsFile=/root/.ssh_local/known_hosts -i /root/.ssh/id_ed25519"
```

---

## 3. Build RTL, SW base e gNodeB

```bash
make all
make gnb
```

---

## 4. Patch CVA6 SDK e build immagini Linux

```bash
git -C sw/deps/cva6-sdk/u-boot apply ../patches/u-boot.patch
git -C sw/deps/cva6-sdk/opensbi apply ../patches/opensbi.patch
git -C sw/deps/cva6-sdk/riscv-isa-sim apply ../patches/riscv-isa-sim.patch
cd sw/deps/cva6-sdk && make images XLEN=64 && cd /workspace
```

L'immagine Linux (`uImage`) si trova in:

```
sw/deps/cva6-sdk/install64/uImage
```

---

## 5. Build immagine GPT per SD card

```bash
make /workspace/sw/boot/linux.genesys2.gpt.bin
```

Il file generato si trova in:

```
sw/boot/linux.genesys2.gpt.bin
```

---

## 6. Build bitstream FPGA (fuori dal container, sul server con Vivado)

```bash
source /path/to/Xilinx/Vivado/2022.1/settings64.sh
export VIVADO=vivado
make chs-xilinx-genesys2
```

Il bitstream si trova in:

```
target/xilinx/out/cheshire.genesys2.bit
```

---

## 7. Flash SD card

Su Linux:

```bash
sudo dd if=sw/boot/linux.genesys2.gpt.bin of=/dev/<sdcard> bs=4M status=progress
sudo sgdisk -e /dev/<sdcard>
```

Su macOS (richiede `brew install gptfdisk`):

```bash
diskutil list
diskutil unmountDisk /dev/diskN
sudo dd if=linux.genesys2.gpt.bin of=/dev/rdiskN bs=4m status=progress
sudo sgdisk -e /dev/diskN
diskutil eject /dev/diskN
```

---

## 8. Flash bitstream sulla board

### Volatile (si perde al power off)

Da Vivado Hardware Manager: Open Target → Auto Connect → Program Device → seleziona il `.bit`

### Persistente (resta dopo power off)

Da Vivado Hardware Manager:

1. Click destro sul device → **Add Configuration Memory Device**
2. Tipo flash: **s25fl256sxxxxxx0-spi-x1_x2_x4**
3. Seleziona il file `.bit`
4. Programma
5. Imposta il **jumper JP5** della Genesys2 su **SPI Flash**

---

## 9. Identificare la board su Linux

Dopo aver collegato la Genesys2 via USB:

```bash
dmesg | tail -20
ls -la /dev/ttyUSB*
```

Tipicamente: `/dev/ttyUSB0` (JTAG) e `/dev/ttyUSB1` (UART console).

Console seriale:

```bash
sudo picocom -b 115200 /dev/ttyUSB1
```
