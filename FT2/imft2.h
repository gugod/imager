#ifndef IMAGER_FT2_H
#define IMAGER_FT2_H

#include "imdatatypes.h"

typedef struct FT2_Fonthandle FT2_Fonthandle;

typedef FT2_Fonthandle* Imager__Font__FT2x;

extern int i_ft2_init(void);
extern FT2_Fonthandle * i_ft2_new(const char *name, int index);
extern void i_ft2_destroy(FT2_Fonthandle *handle);
extern int i_ft2_setdpi(FT2_Fonthandle *handle, int xdpi, int ydpi);
extern int i_ft2_getdpi(FT2_Fonthandle *handle, int *xdpi, int *ydpi);
extern int i_ft2_settransform(FT2_Fonthandle *handle, const double *matrix);
extern int i_ft2_sethinting(FT2_Fonthandle *handle, int hinting);
extern int i_ft2_bbox(FT2_Fonthandle *handle, double cheight, double cwidth, 
                      char const *text, size_t len, int *bbox, int utf8);
extern int i_ft2_bbox_r(FT2_Fonthandle *handle, double cheight, double cwidth, 
		      char const *text, size_t len, int vlayout, int utf8, int *bbox);
extern int i_ft2_text(FT2_Fonthandle *handle, i_img *im, int tx, int ty, 
                      const i_color *cl, double cheight, double cwidth, 
                      char const *text, size_t len, int align, int aa, 
                      int vlayout, int utf8);
extern int i_ft2_cp(FT2_Fonthandle *handle, i_img *im, int tx, int ty, 
                    int channel, double cheight, double cwidth, 
                    char const *text, size_t len, int align, int aa, 
		    int vlayout, int utf8);
extern int i_ft2_has_chars(FT2_Fonthandle *handle, char const *text, size_t len,
                           int utf8, char *work);
extern int i_ft2_face_name(FT2_Fonthandle *handle, char *name_buf, 
                           size_t name_buf_size);
extern int i_ft2_can_face_name(void);
extern int i_ft2_glyph_name(FT2_Fonthandle *handle, unsigned long ch, 
                            char *name_buf, size_t name_buf_size,
                            int reliable_only);
extern int i_ft2_can_do_glyph_names(void);
extern int i_ft2_face_has_glyph_names(FT2_Fonthandle *handle);

extern int i_ft2_get_multiple_masters(FT2_Fonthandle *handle,
                                      i_font_mm *mm);
extern int
i_ft2_is_multiple_master(FT2_Fonthandle *handle);
extern int
i_ft2_set_mm_coords(FT2_Fonthandle *handle, int coord_count, const long *coords);
#endif
