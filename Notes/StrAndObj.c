#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct _buf {
    size_t len;
    uint8_t * payload;
} buf;

typedef struct _Obj {
    int kind;
} Obj;

#define AS_OBJ(o) ((Obj *)(o));
#define IS_STR(o) (((Obj *)(o))->kind == 1)

typedef struct _Str {
    Obj obj;
    buf chars;
} Str;

size_t arr_len(uint8_t * arr)
{
    size_t count = 0;
    while(*(arr + count) != 0x00) {
        count++;
    }
    
    return count;
}

Str * Str_make(buf buffer)
{
    Str * s = calloc(1, sizeof(Str));
    *s = (Str){ 1, buffer };
    return s;
}

void Str_print(Str * s)
{
    if (!(IS_STR(s))) {
        return;
    }
    
    printf("%s", s->chars.payload);
}


int main (int argc, char const *argv[])
{
    uint8_t bytes[] = { 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x2c, 0x20, 0x77, 0x6f, 0x72, 0x6c, 0x64, 0x21, 0x00 };
    buf buffer;
    buffer.len = arr_len(bytes);
    buffer.payload = calloc(buffer.len + 1, sizeof(uint8_t));
    memcpy(buffer.payload, bytes, buffer.len);
    
    Obj * o = AS_OBJ(Str_make(buffer));
    Str_print((Str *)o);
    
    return 0;
}
