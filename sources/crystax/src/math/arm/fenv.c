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

#include <fenv.h>
#include <stdlib.h>
#include <sys/types.h>
#include <signal.h>
#include <unistd.h>

#if !__SOFTFP__

#define _FPSCR_ENABLE_SHIFT 8
#define _FPSCR_ENABLE_MASK (FE_ALL_EXCEPT << _FPSCR_ENABLE_SHIFT)

#define _FPSCR_RMODE_SHIFT 22

const fenv_t __fe_dfl_env = 0;

int fegetenv(fenv_t* __envp)
{
    fenv_t _fpscr;
    __asm__ __volatile__("vmrs %0,fpscr" : "=r" (_fpscr));
    *__envp = _fpscr;
    return 0;
}

int fesetenv(const fenv_t* __envp)
{
    fenv_t _fpscr = *__envp;
    __asm__ __volatile__("vmsr fpscr,%0" : :"ri" (_fpscr));
    return 0;
}

int feclearexcept(int __excepts)
{
    fexcept_t __fpscr;
    fegetenv(&__fpscr);
    __fpscr &= ~__excepts;
    fesetenv(&__fpscr);
    return 0;
}

int fegetexceptflag(fexcept_t* __flagp, int __excepts)
{
    fexcept_t __fpscr;
    fegetenv(&__fpscr);
    *__flagp = __fpscr & __excepts;
    return 0;
}

int fesetexceptflag(const fexcept_t* __flagp, int __excepts)
{
    fexcept_t __fpscr;
    fegetenv(&__fpscr);
    __fpscr &= ~__excepts;
    __fpscr |= *__flagp & __excepts;
    fesetenv(&__fpscr);
    return 0;
}

int feraiseexcept(int __excepts)
{
    fexcept_t __ex = __excepts;
    fesetexceptflag(&__ex, __excepts);
    if ((fegetexcept() & __excepts) != 0)
        kill(getpid(), SIGFPE);
    return 0;
}

int fetestexcept(int __excepts)
{
    fexcept_t __fpscr;
    fegetenv(&__fpscr);
    return (__fpscr & __excepts);
}

int fegetround(void)
{
    fenv_t _fpscr;
    fegetenv(&_fpscr);
    return ((_fpscr >> _FPSCR_RMODE_SHIFT) & 0x3);
}

int fesetround(int __round)
{
    fenv_t _fpscr;
    fegetenv(&_fpscr);
    _fpscr &= ~(0x3 << _FPSCR_RMODE_SHIFT);
    _fpscr |= (__round << _FPSCR_RMODE_SHIFT);
    fesetenv(&_fpscr);
    return 0;
}

int feholdexcept(fenv_t* __envp)
{
    fenv_t __env;
    fegetenv(&__env);
    *__envp = __env;
    __env &= ~(FE_ALL_EXCEPT | _FPSCR_ENABLE_MASK);
    fesetenv(&__env);
    return 0;
}

int feupdateenv(const fenv_t* __envp)
{
    fexcept_t __fpscr;
    fegetenv(&__fpscr);
    fesetenv(__envp);
    feraiseexcept(__fpscr & FE_ALL_EXCEPT);
    return 0;
}

int feenableexcept(int __mask)
{
    fenv_t __old_fpscr, __new_fpscr, __check_fpscr;
    fegetenv(&__old_fpscr);
    __new_fpscr = __old_fpscr | (__mask & FE_ALL_EXCEPT) << _FPSCR_ENABLE_SHIFT;
    fesetenv(&__new_fpscr);
    fegetenv(&__check_fpscr);
    if (__new_fpscr != __check_fpscr)
        return -1;
    return ((__old_fpscr >> _FPSCR_ENABLE_SHIFT) & FE_ALL_EXCEPT);
}

int fedisableexcept(int __mask)
{
    fenv_t __old_fpscr, __new_fpscr, __check_fpscr;
    fegetenv(&__old_fpscr);
    __new_fpscr = __old_fpscr & ~((__mask & FE_ALL_EXCEPT) << _FPSCR_ENABLE_SHIFT);
    fesetenv(&__new_fpscr);
    fegetenv(&__check_fpscr);
    if (__new_fpscr != __check_fpscr)
        return -1;
    return ((__old_fpscr >> _FPSCR_ENABLE_SHIFT) & FE_ALL_EXCEPT);
}

int fegetexcept(void)
{
    fenv_t __fpscr;
    fegetenv(&__fpscr);
    return ((__fpscr & _FPSCR_ENABLE_MASK) >> _FPSCR_ENABLE_SHIFT);
}

#endif /* !__SOFTFP__ */
