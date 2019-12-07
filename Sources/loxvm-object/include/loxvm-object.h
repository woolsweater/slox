#include <stdlib.h>

#ifndef LOXVM_OBJECT_H
#define LOXVM_OBJECT_H

#define LOX_ENUM(TYPE) enum __attribute__((enum_extensibility(closed))) : TYPE

typedef LOX_ENUM(uint32_t) {
    ObjectKindString = 1,
} ObjectKind;

typedef struct {
    ObjectKind kind;
} Object;

typedef struct {
    Object header;
    size_t length;
    uint8_t * _Nonnull chars;
} ObjectString;

typedef Object * _Nullable ObjectRef;
typedef ObjectString * _Nullable StringRef;

#endif /* LOXVM_OBJECT_H */
