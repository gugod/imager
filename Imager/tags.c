/*
=head1 NAME

tags.c - functions for manipulating an images tags list

=head1 SYNOPSIS

  i_img_tags tags;
  i_tags_new(&tags);
  i_tags_destroy(&tags);
  i_tags_addn(&tags, "name", code, idata);
  i_tags_add(&tags, "name", code, data, data_size, idata);
  if (i_tags_find(&tags, name, start, &entry)) { found }
  if (i_tags_findn(&tags, code, start, &entry)) { found }
  i_tags_delete(&tags, index);
  count = i_tags_delbyname(tags, name);
  count = i_tags_delbycode(tags, code);

=head1 DESCRIPTION

Provides functions which give write access to the tags list of an image.

For read access directly access the fields (do not write any fields
directly).

A tag is represented by an i_img_tag structure:

  typedef enum {
    itt_double,
    iit_text
  } i_tag_type;

  typedef struct {
    char *name; // name of a given tag, might be NULL 
    int code; // number of a given tag, -1 if it has no meaning 
    char *data; // value of a given tag if it's not an int, may be NULL 
    int size; // size of the data 
    int idata; // value of a given tag if data is NULL 
  } i_img_tag;


=over

=cut
*/

#include "image.h"
#include <string.h>
#include <stdlib.h>

/*
=item i_tags_new(i_img_tags *tags)

Initialize a tags structure.  Should not be used if the tags structure
has been previously used.

To destroy the contents use i_tags_destroy()

=cut
*/

void i_tags_new(i_img_tags *tags) {
  tags->count = tags->alloc = 0;
  tags->tags = NULL;
}

/*
=item i_tags_addn(i_img_tags *tags, char *name, int code, int idata)

Adds a tag that has an integer value.  A simple wrapper around i_tags_add().

Duplicate tags can be added.

Returns non-zero on success.

=cut
*/

int i_tags_addn(i_img_tags *tags, char *name, int code, int idata) {
  return i_tags_add(tags, name, code, NULL, 0, idata);
}

/*
=item i_tags_add(i_img_tags *tags, char *name, int code, char *data, int size, i_tag_type type, int idata)

Adds a tag to the tags list.

Duplicate tags can be added.

Returns non-zero on success.

=cut
*/

int i_tags_add(i_img_tags *tags, char *name, int code, char *data, int size, 
	       int idata) {
  i_img_tag work = {0};
  if (tags->tags == NULL) {
    int alloc = 10;
    tags->tags = malloc(sizeof(i_img_tag) * alloc);
    if (!tags->tags)
      return 0;
    tags->alloc = alloc;
  }
  else if (tags->count == tags->alloc) {
    int newalloc = tags->alloc + 10;
    void *newtags = realloc(tags->tags, sizeof(i_img_tag) * newalloc);
    if (!newtags) {
      return 0;
    }
    tags->tags = newtags;
    tags->alloc = newalloc;
  }
  if (name) {
    work.name = malloc(strlen(name)+1);
    if (!work.name)
      return 0;
    strcpy(work.name, name);
  }
  if (data) {
    work.data = malloc(size+1);
    if (!work.data) {
      if (work.name) free(work.name);
      return 0;
    }
    memcpy(work.data, data, size);
    work.data[size] = '\0'; /* convenience */
    work.size = size;
  }
  work.code = code;
  work.idata = idata;
  tags->tags[tags->count++] = work;

  return 1;
}

void i_tags_destroy(i_img_tags *tags) {
  if (tags->tags) {
    int i;
    for (i = 0; i < tags->count; ++i) {
      if (tags->tags[i].name)
	free(tags->tags[i].name);
      if (tags->tags[i].data)
	free(tags->tags[i].data);
    }
    free(tags->tags);
  }
}

int i_tags_find(i_img_tags *tags, char *name, int start, int *entry) {
  if (tags->tags) {
    while (start < tags->count) {
      if (tags->tags[start].name && strcmp(name, tags->tags[start].name) == 0) {
	*entry = start;
	return 1;
      }
      ++start;
    }
  }
  return 0;
}

int i_tags_findn(i_img_tags *tags, int code, int start, int *entry) {
  if (tags->tags) {
    while (start < tags->count) {
      if (tags->tags[start].code == code) {
	*entry = start;
	return 1;
      }
      ++start;
    }
  }
  return 0;
}

int i_tags_delete(i_img_tags *tags, int entry) {
  if (tags->tags && entry >= 0 && entry < tags->count) {
    i_img_tag old = tags->tags[entry];
    memmove(tags->tags+entry, tags->tags+entry+1,
	    tags->count-entry-1);
    if (old.name)
      free(old.name);
    if (old.data)
      free(old.data);
    --tags->count;
    return 1;
  }
  return 0;
}

int i_tags_delbyname(i_img_tags *tags, char *name) {
  int count = 0;
  int i;
  if (tags->tags) {
    for (i = tags->count-1; i >= 0; --i) {
      if (tags->tags[i].name && strcmp(name, tags->tags[i].name) == 0) {
        ++count;
        i_tags_delete(tags, i);
      }
    }
  }
  return count;
}

int i_tags_delbycode(i_img_tags *tags, int code) {
  int count = 0;
  int i;
  if (tags->tags) {
    for (i = tags->count-1; i >= 0; --i) {
      if (tags->tags[i].code == code) {
        ++count;
        i_tags_delete(tags, i);
      }
    }
  }
  return count;
}

