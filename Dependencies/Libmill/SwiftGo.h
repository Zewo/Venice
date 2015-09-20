// Go.h
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

#ifndef Go_h
#define Go_h

#include <stdlib.h>
typedef struct mill_chan *chan;

int64_t go_now();
void go_sleep(int64_t deadline);
void go_routine(void (^routine)(void));
void go_yield();
chan go_make_channel(size_t sz, size_t bufsz);
chan go_copy_channel(chan ch);
void go_send_to_channel(chan ch, void *val, size_t sz);
void *go_receive_from_channel(chan ch, size_t sz);
void go_close_channel(chan ch, void *val, size_t sz);
void go_free_channel(chan ch);
void go_select_init();
size_t go_clause_length();
void go_select_in(void *clause, chan ch, size_t sz, int idx);
void *go_select_value(size_t sz);
void go_select_out(void *clause, chan ch, void *val, size_t sz, int idx);
void go_select_otherwise();
int go_select_wait();

#endif /* defined(Go_h) */
