    .global RESOURCES_MY_OFFSET;
    .global RESOURCES_MY_SIZE;

    .global RESOURCES_PACKAGE
    .section .rodata
RESOURCES_PACKAGE:
    .incbin "resources.bin"
RESOURCES_MY_OFFSET:
    .int 0
RESOURCES_MY_SIZE:
    .int 44539

