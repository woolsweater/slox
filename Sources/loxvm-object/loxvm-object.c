#include "loxvm-object.h"

int8_t * StringRef_chars(StringRef string)
{
    void * base = string;
    return (int8_t *)(base + __offsetof(ObjectString, chars));
}
