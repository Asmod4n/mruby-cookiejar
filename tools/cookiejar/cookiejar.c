#include <mruby.h>
#ifdef MRB_INT16
#error "MRB_INT16 is too small for mruby-cookiejar"
#endif
#ifdef MRB_COOKIEJAR_HAS_ERR_AND_SYSEXITS_H
#include <err.h>
#include <sysexits.h>
#endif
#include <stdlib.h>
#include <mruby/throw.h>
#include <mruby/array.h>
#include <string.h>

int main(const int argc, const char** const argv)
{
  mrb_state *mrb = mrb_open();
  if (!mrb) {
#ifdef MRB_COOKIEJAR_HAS_ERR_AND_SYSEXITS_H
    err(EX_OSERR, NULL);
#else
    return EXIT_FAILURE;
#endif
  }

  struct mrb_jmpbuf* prev_jmp = mrb->jmp;
  struct mrb_jmpbuf c_jmp;
  int ret = EXIT_FAILURE;

  MRB_TRY(&c_jmp)
  {
    mrb->jmp = &c_jmp;
    int arena_index = mrb_gc_arena_save(mrb);
    mrb_value ARGV = mrb_ary_new_capa(mrb, argc);
    mrb_define_global_const(mrb, "ARGV", ARGV);
    int i;
    for (i = 0; i < argc; i++) {
      mrb_value argv_current = mrb_str_new_static(mrb, argv[i], strlen(argv[i]));
      mrb_ary_push(mrb, ARGV, argv_current);
      mrb_gc_arena_restore(mrb, arena_index);
    }

    mrb_funcall(mrb, mrb_top_self(mrb), "cookiejar", 0);
    ret = EXIT_SUCCESS;
    mrb->jmp = prev_jmp;
  }
  MRB_CATCH(&c_jmp)
  {
      mrb->jmp = prev_jmp;
#ifdef MRB_DEBUG
      mrb_print_error(mrb);
#endif
  }
  MRB_END_EXC(&c_jmp);

  mrb_close(mrb);

  return ret;
}
