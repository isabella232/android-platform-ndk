/*
 * Copyright (c) 2011-2015 CrystaX.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are
 * permitted provided that the following conditions are met:
 *
 *    1. Redistributions of source code must retain the above copyright notice, this list of
 *       conditions and the following disclaimer.
 *
 *    2. Redistributions in binary form must reproduce the above copyright notice, this list
 *       of conditions and the following disclaimer in the documentation and/or other materials
 *       provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY CrystaX ''AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 * FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL CrystaX OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * The views and conclusions contained in the software and documentation are those of the
 * authors and should not be interpreted as representing official policies, either expressed
 * or implied, of CrystaX.
 */

#include <crystax.h>
#include <crystax/jutils.hpp>
#include <crystax/memory.hpp>
#include <crystax/private.h>
#include <errno.h>

namespace crystax
{
namespace jni
{

namespace details
{

const char * jcast_helper<const char *, jstring>::cast(jstring const &v)
{
    JNIEnv *env = jnienv();
    const char *s = env->GetStringUTFChars(v, JNI_FALSE);
    const char *ret = ::strdup(s);
    env->ReleaseStringUTFChars(v, s);
    return ret;
}

jhstring jcast_helper<jhstring, const char *>::cast(const char *s)
{
    JNIEnv *env = jnienv();
    jstring obj = env->NewStringUTF(s);
    return jhstring(obj);
}

#define CRYSTAX_PP_CAT(a, b, c) CRYSTAX_PP_CAT_IMPL(a, b, c)
#define CRYSTAX_PP_CAT_IMPL(a, b, c) a ## b ## c

#define CRYSTAX_PP_STRINGIZE(a) CRYSTAX_PP_STRINGIZE_IMPL(a)
#define CRYSTAX_PP_STRINGIZE_IMPL(a) #a

#define JNI_MAP_void Void
#define JNI_MAP_jboolean Boolean
#define JNI_MAP_jbyte Byte
#define JNI_MAP_jchar Char
#define JNI_MAP_jshort Short
#define JNI_MAP_jint Int
#define JNI_MAP_jlong Long
#define JNI_MAP_jfloat Float
#define JNI_MAP_jdouble Double
#define JNI_MAP_jhobject Object
#define JNI_MAP_jhclass Object
#define JNI_MAP_jhstring Object
#define JNI_MAP_jhthrowable Object
#define JNI_MAP_jharray Object
#define JNI_MAP_jhbooleanArray Object
#define JNI_MAP_jhbyteArray Object
#define JNI_MAP_jhshortArray Object
#define JNI_MAP_jhintArray Object
#define JNI_MAP_jhlongArray Object
#define JNI_MAP_jhfloatArray Object
#define JNI_MAP_jhdoubleArray Object
#define JNI_MAP_jhobjectArray Object

#define JNI_MAP(type) JNI_MAP_ ## type

template <typename T>
struct jni_base_type
{
    typedef T type_t;
};

template <typename T>
struct jni_base_type<jholder<T> >
{
    typedef T type_t;
};

void call_void_method(JNIEnv *env, jobject obj, jmethodID mid, ...)
{
    va_list vl;
    va_start(vl, mid);
    env->CallVoidMethodV(obj, mid, vl);
    va_end(vl);
}

void call_void_method(JNIEnv *env, jclass cls, jmethodID mid, ...)
{
    va_list vl;
    va_start(vl, mid);
    env->CallStaticVoidMethodV(cls, mid, vl);
    va_end(vl);
}

template <typename T>
struct result_helper
{
    static T make_result(JNIEnv * /*env*/, T obj) {return obj;}
};

template <typename T>
struct result_helper<jholder<T> >
{
    static jholder<T> make_result(JNIEnv *env, T obj) {return jholder<T>(env->ExceptionCheck() ? 0 : obj);}
};

#define CRYSTAX_PP_STEP(type) \
    type CRYSTAX_PP_CAT(get_, type, _field)(JNIEnv *env, jobject obj, jfieldID fid) \
    { \
        DBG("calling Get" CRYSTAX_PP_STRINGIZE(JNI_MAP(type)) "Field"); \
        return type((jni_base_type<type>::type_t)CRYSTAX_PP_CAT(env->Get, JNI_MAP(type), Field)(obj, fid)); \
    } \
    type CRYSTAX_PP_CAT(get_, type, _field)(JNIEnv *env, jclass cls, jfieldID fid) \
    { \
        DBG("calling GetStatic" CRYSTAX_PP_STRINGIZE(JNI_MAP(type)) "Field"); \
        return type((jni_base_type<type>::type_t)CRYSTAX_PP_CAT(env->GetStatic, JNI_MAP(type), Field)(cls, fid)); \
    } \
    void CRYSTAX_PP_CAT(set_, type, _field)(JNIEnv *env, jobject obj, jfieldID fid, type const &arg) \
    { \
        DBG("calling Set" CRYSTAX_PP_STRINGIZE(JNI_MAP(type)) "Field"); \
        CRYSTAX_PP_CAT(env->Set, JNI_MAP(type), Field)(obj, fid, (jni_base_type<type>::type_t)raw_arg(arg)); \
    } \
    void CRYSTAX_PP_CAT(set_, type, _field)(JNIEnv *env, jclass cls, jfieldID fid, type const &arg) \
    { \
        DBG("calling SetStatic" CRYSTAX_PP_STRINGIZE(JNI_MAP(type)) "Field"); \
        CRYSTAX_PP_CAT(env->SetStatic, JNI_MAP(type), Field)(cls, fid, (jni_base_type<type>::type_t)raw_arg(arg)); \
    } \
    type CRYSTAX_PP_CAT(call_, type, _method)(JNIEnv *env, jobject obj, jmethodID mid, ...) \
    { \
        DBG("calling Call" CRYSTAX_PP_STRINGIZE(JNI_MAP(type)) "MethodV"); \
        va_list vl; \
        va_start(vl, mid); \
        typedef jni_base_type<type>::type_t result_t; \
        result_t result = (result_t)CRYSTAX_PP_CAT(env->Call, JNI_MAP(type), MethodV)(obj, mid, vl); \
        va_end(vl); \
        return result_helper<type>::make_result(env, result); \
    } \
    type CRYSTAX_PP_CAT(call_, type, _method)(JNIEnv *env, jclass cls, jmethodID mid, ...) \
    { \
        DBG("calling CallStatic" CRYSTAX_PP_STRINGIZE(JNI_MAP(type)) "MethodV"); \
        va_list vl; \
        va_start(vl, mid); \
        typedef jni_base_type<type>::type_t result_t; \
        result_t result = (result_t)CRYSTAX_PP_CAT(env->CallStatic, JNI_MAP(type), MethodV)(cls, mid, vl); \
        va_end(vl); \
        return result_helper<type>::make_result(env, result); \
    }
#include <crystax/details/jni.inc>
#undef CRYSTAX_PP_STEP

template <> const char *jni_signature<jboolean>::signature = "Z";
template <> const char *jni_signature<jbyte>::signature = "B";
template <> const char *jni_signature<jchar>::signature = "C";
template <> const char *jni_signature<jshort>::signature = "S";
template <> const char *jni_signature<jint>::signature = "I";
template <> const char *jni_signature<jlong>::signature = "J";
template <> const char *jni_signature<jfloat>::signature = "F";
template <> const char *jni_signature<jdouble>::signature = "D";
template <> const char *jni_signature<jhobject>::signature = "Ljava/lang/Object;";
template <> const char *jni_signature<jhclass>::signature = "Ljava/lang/Class;";
template <> const char *jni_signature<jhstring>::signature = "Ljava/lang/String;";
template <> const char *jni_signature<jhthrowable>::signature = "Ljava/lang/Throwable;";
template <> const char *jni_signature<jhbooleanArray>::signature = "[Z";
template <> const char *jni_signature<jhbyteArray>::signature = "[B";
template <> const char *jni_signature<jhcharArray>::signature = "[C";
template <> const char *jni_signature<jhshortArray>::signature = "[S";
template <> const char *jni_signature<jhintArray>::signature = "[I";
template <> const char *jni_signature<jhlongArray>::signature = "[J";
template <> const char *jni_signature<jhfloatArray>::signature = "[F";
template <> const char *jni_signature<jhdoubleArray>::signature = "[D";
template <> const char *jni_signature<jhobjectArray>::signature = "[Ljava/lang/Object;";

} // namespace details

bool jexcheck(JNIEnv *env)
{
    jhthrowable jex(env->ExceptionOccurred());
    if (!jex)
        return true;

    jmethodID mid = get_method_id(env, jex, "getMessage", "()Ljava/lang/String;");

    scope_c_ptr_t<const char> s(jcast<const char *>((jstring)env->CallObjectMethod(jex.get(), mid)));
    ERR("java exception: %s", s.get());

    env->ExceptionDescribe();

    env->ExceptionClear();

    errno = EFAULT;
    return false;
}

} // namespace jni
} // namespace crystax
