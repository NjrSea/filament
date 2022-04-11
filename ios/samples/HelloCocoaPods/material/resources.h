#ifndef RESOURCES_H_
#define RESOURCES_H_

#include <stdint.h>

extern "C" {
    extern const uint8_t RESOURCES_PACKAGE[];
    extern int RESOURCES_MY_OFFSET;
    extern int RESOURCES_MY_SIZE;
}
#define RESOURCES_MY_DATA (RESOURCES_PACKAGE + RESOURCES_MY_OFFSET)

#endif
