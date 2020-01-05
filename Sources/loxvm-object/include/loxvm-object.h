#include <stdlib.h>

#ifndef LOXVM_OBJECT_H
#define LOXVM_OBJECT_H

#define LOX_ENUM(TYPE) enum __attribute__((enum_extensibility(closed))) : TYPE

/**
 Tag to distinguish different object subtypes, which each have
 their own associated data.
 */
typedef LOX_ENUM(uint32_t) {

    /** A Lox String */
    ObjectKindString = 1,

} ObjectKind;

/**
 Common data required for a value in a Lox program that requires more
 storage than a simple scalar. All more specific object structs include
 this as a "header".
 - remark: These definitions are made in C rather than Swift so that the
 layout is guaranteed. Structs sharing the `Object` header can be handled
 generically through pointers because of that guarantee.
 */
typedef struct _Object {
    /** Tag for the subtype. */
    ObjectKind kind;
    /** Used by the memory manager to link all created objects. */
    struct _Object * _Nullable next;
} Object;

/** Implementation data for a Lox String. */
typedef struct {
    /** Common bookkeeping data. */
    Object header;
    /** strlen of the `chars` buffer, i.e., not counting the NUL */
    size_t length;
    /** NUL-terminated UTF-8 contents of the string. */
    int8_t * _Nonnull chars;
} ObjectString;

/**
 A heap-allocated generic `Object`; the `kind` tag is used to
 determine the actual subtype so the object can be correctly cast.
 */
typedef Object * ObjectRef;

/** A heap-allocated `ObjectString`. */
typedef ObjectString * StringRef;

#endif /* LOXVM_OBJECT_H */
