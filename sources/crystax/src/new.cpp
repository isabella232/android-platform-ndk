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

#include <new>
#include <crystax/private.h>

void * operator new (std::size_t n)
{
    return ::malloc(n);
}

void * operator new[] (std::size_t n)
{
    return ::malloc(n);
}

void operator delete (void *ptr) throw()
{
    ::free(ptr);
}

void operator delete[] (void *ptr) throw()
{
    ::free(ptr);
}

void * operator new (std::size_t n, std::nothrow_t const &)
{
    return ::malloc(n);
}

void * operator new[] (std::size_t n, std::nothrow_t const &)
{
    return ::malloc(n);
}

void operator delete (void *ptr, std::nothrow_t const &) throw()
{
    ::free(ptr);
}

void operator delete[] (void *ptr, std::nothrow_t const &) throw()
{
    ::free(ptr);
}
