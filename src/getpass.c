/*
 * Copyright (c) 1999 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 *
 * Copyright (c) 1999-2003 Apple Computer, Inc.  All Rights Reserved.
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_LICENSE_HEADER_END@
 */
/*
 * Copyright (c) 1988, 1993
 *  The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *  This product includes software developed by the University of
 *  California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <signal.h>
#include <stdio.h>
#include <termios.h>
#include <mruby.h>
#include <mruby/throw.h>
#include <mruby/string.h>
#include <paths.h>
#include <errno.h>
#include <unistd.h>

static mrb_value
mrb_getpass(mrb_state *mrb, mrb_value self)
{
  const char *prompt = "Password:";
  sigset_t stop;
  sigemptyset (&stop);
  sigaddset(&stop, SIGINT);
  sigaddset(&stop, SIGTSTP);
  FILE *outfp, *fp;
  struct termios term;
  int echo;
  struct mrb_jmpbuf* prev_jmp = mrb->jmp;
  struct mrb_jmpbuf c_jmp;
  int ch;
  mrb_value buf = mrb_str_buf_new(mrb, 0);

  mrb_get_args(mrb, "|z", &prompt);

  /*
   * note - blocking signals isn't necessarily the
   * right thing, but we leave it for now.
   */
  sigprocmask(SIG_BLOCK, &stop, NULL);

  /*
   * read and write to /dev/tty if possible; else read from
   * stdin and write to stderr.
   */
  if ((outfp = fp = fopen(_PATH_TTY, "w+")) == NULL) {
    if (errno == ENOMEM) {
      sigprocmask(SIG_UNBLOCK, &stop, NULL);
      mrb_exc_raise(mrb, mrb_obj_value(mrb->nomem_err));
    }
    outfp = stderr;
    fp = stdin;
  }

  tcgetattr(fileno(fp), &term);
  if ((echo = (term.c_lflag & ECHO))) {
    term.c_lflag &= ~ECHO;
    tcsetattr(fileno(fp), TCSAFLUSH|TCSASOFT, &term);
  }
  fputs(prompt, outfp);
  rewind(outfp);      /* implied flush */

  MRB_TRY(&c_jmp)
  {
      mrb->jmp = &c_jmp;
      while ((ch = getc(fp)) != EOF && ch != '\n') {
        mrb_str_cat(mrb, buf, (const char *) &ch, 1);
      }
      mrb->jmp = prev_jmp;
  }
  MRB_CATCH(&c_jmp)
  {
      mrb->jmp = prev_jmp;
      if (echo) {
        term.c_lflag |= ECHO;
        tcsetattr(fileno(fp), TCSAFLUSH|TCSASOFT, &term);
      }
      if (fp != stdin) {
        fclose(fp);
      }
      sigprocmask(SIG_UNBLOCK, &stop, NULL);
      if (mrb_test(buf)) {
        mrb_funcall(mrb, mrb_obj_value(mrb_module_get(mrb, "Sodium")), "memzero", 2, buf, mrb_fixnum_value(RSTRING_LEN(buf)));
      }
      MRB_THROW(mrb->jmp);
  }
  MRB_END_EXC(&c_jmp);

  if (feof(fp)) {
    buf = mrb_nil_value();
  }
  write(fileno(outfp), "\n", 1);
  if (echo) {
    term.c_lflag |= ECHO;
    tcsetattr(fileno(fp), TCSAFLUSH|TCSASOFT, &term);
  }
  if (fp != stdin) {
    fclose(fp);
  }
  sigprocmask(SIG_UNBLOCK, &stop, NULL);

  return buf;
}

void
mrb_mruby_cookiemonster_gem_init(mrb_state* mrb)
{
  mrb_define_class_method(mrb, mrb_define_class(mrb, "Cookiemonster", mrb->object_class), "getpass", mrb_getpass, MRB_ARGS_OPT(1));
}

void mrb_mruby_cookiemonster_gem_final(mrb_state* mrb) {}
