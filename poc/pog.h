//
//  pog.h
//  poc14.7.1
//
//  Created by barisc on 13.10.2021.
//

#ifndef poc_h
#define poc_h

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <mach/mach.h>
#include <pthread.h>

#include "iokit.h"

io_connect_t get_iomfb_uc(void);
int do_trigger(io_connect_t iomfb_uc);
int poc(void);

#endif /* poc_h */
