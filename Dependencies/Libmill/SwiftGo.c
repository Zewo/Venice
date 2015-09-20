// Go.c
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Zewo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#include "SwiftGo.h"
#include "libmill.h"

int64_t go_now() {
    return now();
}

void go_sleep(int64_t deadline) {
    mill_msleep(deadline, "");
}

void go_routine(void (^routine)(void)) {
    void *mill_sp = mill_go_prologue("");
    if(mill_sp) {
        int mill_anchor[mill_unoptimisable1];
        mill_unoptimisable2 = &mill_anchor;
        char mill_filler[(char*)&mill_anchor - (char*)(mill_sp)];
        mill_unoptimisable2 = &mill_filler;
        routine();
        mill_go_epilogue();
    }
}

void go_yield() {
    mill_yield("");
}

chan go_make_channel(size_t sz, size_t bufsz) {
    return mill_chmake(sz, bufsz, "");
}

void go_send_to_channel(chan ch, void *val, size_t sz) {
    mill_chs(ch, val, sz, "");
}

void *go_receive_from_channel(chan ch, size_t sz) {
    return mill_chr(ch, sz, "");
}

void go_close_channel(chan ch, void *val, size_t sz) {
    mill_chdone(ch, val, sz, "");
}

void go_free_channel(chan ch) {
    mill_chclose(ch, "");
}

chan go_copy_channel(chan ch) {
    return mill_chdup(ch, "");
}

void go_select_init() {
    mill_choose_init("");
}

size_t go_clause_length() {
    return MILL_CLAUSELEN;
}

void go_select_in(void *clause, chan ch, size_t sz, int idx) {
    mill_choose_in(clause, ch, sz, idx);
}

void *go_select_value(size_t sz) {
    return mill_choose_val(sz);
}

void go_select_out(void *clause, chan ch, void *val, size_t sz, int idx) {
    mill_choose_out(clause, ch, val, sz, idx);
}

void go_select_otherwise() {
    mill_choose_otherwise();
}

int go_select_wait() {
    return mill_choose_wait();
}