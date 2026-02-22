/* PTRLOAD - replicates ADV's handling of index files
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

typedef signed short WORD;

#define MAX_KEY 9004	/* The supplied ADV does not use keys past 9003,
                         * so our array will never have more than 9004
                         * entries.  */

static WORD subkey[18], key[18];
static WORD results[2 * MAX_KEY];
static int count;

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


int main(int argc, char **argv)
{
	FILE *fp;
        WORD *buf;
        WORD lastkey = -1;
        WORD n = 0;
        WORD idx_recno = 0;

	/* Insist on a file to open */
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
	buf = results;
        count = 0;

        while (1)
        {
                if (n == 18) n = 0;	/* 18 entries in a record   */
                if (!n) 		/* n == 0: read next record */
		{	
			++idx_recno; 
			wread(subkey, 18, fp);		/* Load subkeys */
			wread(key,    18, fp);		/* Load keys */
			fseek(fp, 56, SEEK_CUR);	/* Skip offset record */
		}
                if (subkey[n] == -1) break;
                if (key[n] == lastkey) 	/* Same key */
		{ 
			++n; 
			continue; 
		}
                lastkey = key[n];
                ++count;
                *(buf++) = key[n];	/* Store the key */
                *(buf++) = idx_recno;	/* Say where its details are */
		++n;
        }
	/* Dump out the array we just loaded. 0x96DE is the address at 
         * which ADVI.PTR is loaded by version B02; the output format 
         * resembles a debugger memory dump, so that results can be 
         * easily compared with the real thing */
	for (n = 0; n < count; n+=8)
	{
		int m;
		printf("%04x: ", 0x96DE + 2 * n);
		for (m = 0; m < 8; m++)
		{
			printf("%04x  ", results[m+n]);
		}
		printf("\n");
	}
	fclose(fp);
	return 0;
}
