CC:=gcc
CFLAGS:=-Wall -Wno-overflow

all: clean trustzone_bin_config

trustzone_bin_config: trustzone_bin_config.c $(wildcard *.h)
	$(CC) $(CFLAGS) -o $@ $(firstword $^)
	./$@

clean:
	rm -f trustzone_bin_config trustzone_config.bin

.PHONY: all clean