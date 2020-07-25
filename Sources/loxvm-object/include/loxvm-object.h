#include <stdlib.h>

#ifndef LOXVM_OBJECT_H
#define LOXVM_OBJECT_H

#define LOX_ENUM(TYPE) enum __attribute__((enum_extensibility(closed))) : TYPE
#define LOX_REFINED_FOR_SWIFT __attribute__((swift_private))

#pragma clang assume_nonnull begin

/**
 Tag to distinguish different object subtypes, which each have
 their own associated data.
 */
typedef LOX_ENUM(uint8_t) {

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
    /**
     Lox-internal hash of the contents of the string.
     Primarily used for variable lookup.
     */
    uint32_t hash;
    /**
     NUL-terminated UTF-8 contents of the string.
     - remark: This is a flexible array member and will have a size
     determined at runtime, but it must have a declared size in order
     to be imported into Swift.
    */
    int8_t chars[0];
} ObjectString;

/**
 A heap-allocated generic `Object`; the `kind` tag is used to
 determine the actual subtype so the object can be correctly cast.
 */
typedef Object * ObjectRef;

/** A heap-allocated `ObjectString`. */
typedef ObjectString * StringRef;

/**
 Given a pointer to an `ObjectString`, return a pointer to its
 `chars` field.
 - remark: Swift code cannot calculate the offset of the field
 if it is declared with 0 length.
 https://bugs.swift.org/browse/SR-12088
 */
int8_t * StringRef_chars(StringRef string)
    LOX_REFINED_FOR_SWIFT;

#pragma clang assume_nonnull end

#endif /* LOXVM_OBJECT_H */
