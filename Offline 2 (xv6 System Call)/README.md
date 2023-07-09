Prerequisite tools: https://pdos.csail.mit.edu/6.828/2022/tools.html

Cloning codebase:
```
git clone https://github.com/mit-pdos/xv6-riscv
```
Compile and run (from inside xv6-riscv directory):
```
make clean; make qemu
```
Generating patch (from inside xv6-riscv directory):
```
git add --all; git diff HEAD > <patch file name>
```
Applying patch:
```
git apply --whitespace=fix <patch file name>
```
Cleanup git directory:
```
git clean -fdx; git reset --hard
```
