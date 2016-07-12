#include <mruby.h>
#ifdef MRB_INT16
#error "MRB_INT16 is too small for mruby-cookiemonster"
#endif
#ifdef MRB_COOKIEMONSTER_HAS_ERR_AND_SYSEXITS_H
#include <err.h>
#include <sysexits.h>
#endif
#include <stdlib.h>
#include <mruby/throw.h>
#include <mruby/array.h>
#include <string.h>

int main(const int argc, const char *argv[])
{
  mrb_state *mrb = mrb_open();
  if (!mrb) {
#ifdef MRB_COOKIEMONSTER_HAS_ERR_AND_SYSEXITS_H
    err(EX_OSERR, NULL);
#else
    return EXIT_FAILURE;
#endif
  }

  int ret = EXIT_SUCCESS;
  struct mrb_jmpbuf* prev_jmp = mrb->jmp;
  struct mrb_jmpbuf c_jmp;

  MRB_TRY(&c_jmp)
  {
    mrb->jmp = &c_jmp;

    int arena_index = mrb_gc_arena_save(mrb);
    mrb_value ARGV = mrb_ary_new_capa(mrb, argc);
    mrb_define_global_const(mrb, "ARGV", ARGV);
    for (int i = 0; i < argc; i++) {
      mrb_value argv_current = mrb_str_new_static(mrb, argv[i], strlen(argv[i]));
      mrb_ary_push(mrb, ARGV, argv_current);
      mrb_gc_arena_restore(mrb, arena_index);
    }

    mrb_funcall(mrb, mrb_top_self(mrb), "cookiemonster", 0);

    mrb->jmp = prev_jmp;
  }
  MRB_CATCH(&c_jmp)
  {
      mrb->jmp = prev_jmp;
      ret = EXIT_FAILURE;
      mrb_print_error(mrb);
  }
  MRB_END_EXC(&c_jmp);

  mrb_close(mrb);

  return ret;
}
