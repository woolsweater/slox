#include "loxvm-object.h"

int8_t * ObjectString_chars(StringRef string)
{
    void * base = string;
    return (int8_t *)(base + __offsetof(ObjectString, chars));
}
