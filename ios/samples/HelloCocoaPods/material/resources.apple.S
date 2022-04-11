    .global _RESOURCES_MY_OFFSET;
    .global _RESOURCES_MY_SIZE;

    .global _RESOURCES_PACKAGE
    .section __TEXT,__const
_RESOURCES_PACKAGE:
    .incbin "resources.bin"
_RESOURCES_MY_OFFSET:
    .int 0
_RESOURCES_MY_SIZE:
    .int 44539

