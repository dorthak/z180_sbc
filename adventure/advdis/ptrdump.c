/* PTRDUMP - list out an Adventure 550 / Adventure 580 index
    Copyright (C) 2000  John Elliott

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include <stdio.h>


/* Typedefs */
typedef signed short WORD;
typedef unsigned char BYTE;

typedef struct
{
	WORD subkeys[18];
	WORD keys   [18];
	WORD recs   [18];
	BYTE offs   [18];
	BYTE spare  [2];
} IDXREC;

static IDXREC index;

/* Read some little-endian words from the file */
int wread(WORD *w, int count, FILE *fp)
{
	int n, c;

	for (n = 0; n < count; n++)
	{ 
		c  = fgetc(fp);
		if (c == EOF) return 0;
		*w = c;
		c = fgetc(fp);
		if (c == EOF) return 0;
		*w |= (c << 8);
		++w;
	}
	return 1;
}


/* The main program */
int main(int argc, char **argv)
{
	FILE *fp;
        WORD n = 0;	/* Count (1-18) within record */
	int recno = 0;	/* Record number within file */

	/* Insist on a file to dump */
	if (argc < 2) 
	{ 
		fprintf(stderr, "Syntax: %s file.PTR\n", argv[0]);
		exit(1);
	}
	fp = fopen(argv[1], "rb");
	if (!fp) 
	{
		perror(argv[1]); 
		exit(1);
	}

	/* Read records until either we get a subkey of -1 or 
         * the file gives out */
        while (1)
        {
                if (n == 18) n = 0;	/* 18 entries in a record   */
                if (!n) 		/* n == 0: read next record */
		{	
			++recno; 
			wread(index.subkeys, 18, fp);
			wread(index.keys,    18, fp);
			wread(index.recs,    18, fp);
			fread(index.offs, 1, 20, fp);
	
			if (feof(fp)) break;	
		}
		if (index.subkeys[n] == -1) break;
		printf("%04d, %02d : SUBKEY=%04d KEY=%04d RECORD=%04d "
			 "OFFSET=%03d\n",
			recno, n, index.subkeys[n], index.keys[n], 
                                  index.recs[n],    index.offs[n]);
       		++n; 
	}
	fclose(fp);
	return 0;
}
