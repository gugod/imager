/* Declares utility functions useful across various files which
   aren't meant to be available externally
*/

#ifndef IMAGEI_H_
#define IMAGEI_H_

#include "image.h"

/* wrapper functions that implement the floating point sample version of a 
   function in terms of the 8-bit sample version
*/
extern int i_ppixf_fp(i_img *im, int x, int y, i_fcolor *pix);
extern int i_gpixf_fp(i_img *im, int x, int y, i_fcolor *pix);
extern int i_plinf_fp(i_img *im, int l, int r, int y, i_fcolor *pix);
extern int i_glinf_fp(i_img *im, int l, int r, int y, i_fcolor *pix);
extern int i_gsampf_fp(i_img *im, int l, int r, int y, i_fsample_t *samp,
                       int *chans, int chan_count);

#endif
