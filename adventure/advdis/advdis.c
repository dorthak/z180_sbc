/* ADVDIS - Reverse engineer  Adventure 550 / Adventure 580 to A-code
    Copyright (C) 2000, 2020  John Elliott <seasip.webmaster@gmail.com>

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
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/* The two .DAT files */
static FILE *fpadvi, *fpadvt;

/* Prototypes */
static long lookup_advi(int key, int subkey);	/* Look up keys */
static long lookup_advt(int key, int subkey);
static int  getword(long offset);		/* Read coded byte/word */
static int  getbyte(long offset);
static char *sym_lookup(int symbol);		/* Look up external symbol */

/* Command-line options */

static int nosym;
static int nomsg;
static int noloc;
static int noini;
static int norep;
static int noact;
static int noprc;
static int noobj;
static int symtab;

/* Support for external symbol table */

#define MAXSYM 10000
#define SYMBOLFILE "symbol.tab"
static char *symbols[MAXSYM];
static int symcount = 0;

typedef struct 
{
	int idx_max;	/* No. of entries in this index */
	int *idxdat;	/* Memory allocated to hold index */
	int *subkey;	/* The 4 index fields, as arrays */
	int *key;
	int *record;
	int *offset;
} INDEX;

INDEX advi, advt;	/* The text & integer indexes */

int compressed;	/* Version B02 compression */
int huffman;	/* Version B03 encoding */

unsigned char comp_dat[256];	/* COMPRESS.DAT */
unsigned char dec_dat[512];	/* DECODE.DAT */

/* Output a text byte */
void prbyte(int c)
{
	c &= 0xFF;

	if (c >= 0x80)	/* Token */
	{
		/* Look it up in compress.dat */
		char *t = (char *)(comp_dat + comp_dat[128 + (c & 0x1F)] - 1);
		int   s =  comp_dat[160 + (c & 0x1F)];
		int n;

		for (n = 0; n < s; n++) 
		{
			char c1 = t[n];
			
			if (n == 0 && (c & 0x40)) /* Capital letter flag */
			{ 
				c1 = toupper(c1);
			}
			putchar(c1);
		}
		if (c & 0x20) putchar(' ');	  /* Trailing space flag */
	}
	else if (c < 0x20)	/* Repeated spaces */
	{
		int n;
		for (n = 0; n < c; n++) putchar(' ');
	}
	else putchar(c);	/* Normal character */
}




/* Show a symbol from the internal symbol table in ADVI.DAT */

int showsym(int sym)
{
	int w, x, y, z[3];
	long offset = lookup_advi(9000, 0);

        if (offset > 0)
        {
                w = getword(offset);   

                offset = lookup_advi(9001, 0);
                for (x = 0; x < w; x++)
                {
                        z[0] = getword(offset); offset += 2;
                        z[1] = getword(offset); offset += 2;
                        z[2] = getword(offset); offset += 2;
                        y    = getword(offset); offset += 2;

			if (y == sym)
			{
				 printf("%c%c%c%c%c%c ", 
                                       (z[0] & 0xFF), (z[0] >> 8),
                                       (z[1] & 0xFF), (z[1] >> 8),
                                       (z[2] & 0xFF), (z[2] >> 8));
				return 1;
			}
		}
        }
	return 0;
}

/* Convert a .PTR file to an in-memory index structure */

int load_ptrfile(INDEX *idx, char *ptrname)
{
	int idxlen;
	int n, m;
	long len;
	unsigned char v[128];
	FILE *fp = fopen(ptrname, "rb");

	if (!fp) return -1;

	
	fseek(fp, 0, SEEK_END);
	len = ftell(fp);		/* Length of file */
	fseek(fp, 0, SEEK_SET);

	len /= 128;			/* No. of records in index file */
	if (!len) { fclose(fp); return -1; }

	idxlen = len * 18;	/* 18 entries/record */
	idx->idxdat = malloc(idxlen * 4 * sizeof(int)); /* 4 arrays */
	if (!idx->idxdat) { fclose(fp); return -1; }
	idx->subkey = idx->idxdat;			/* Set array addrs */
	idx->key    = idx->idxdat + idxlen;
	idx->record = idx->idxdat + idxlen * 2;
	idx->offset = idx->idxdat + idxlen * 3;

	m = 0;
	while (len)	/* Load records one at a time */
	{
		if (fread(v, 1, 128, fp) < 128) 
		{
			fclose(fp);
			free(idx->idxdat);
			return -1;
		}
		for (n = 0; n < 18; n++) /* Fill structures */
		{
			idx->subkey[m] = v[2 * n      ] + 256 * v[2 * n +  1];
			idx->key   [m] = v[2 * n +  36] + 256 * v[2 * n + 37];
			idx->record[m] = v[2 * n +  72] + 256 * v[2 * n + 73];
			idx->offset[m] = v[    n + 108];
			++m;
		}
		len--;	
	}
	idx->idx_max = m;
	fclose(fp);
	return 0;
}

/* Look up a key/subkey pair in an index */
int lookupg(INDEX *idx, int key, int subkey)
{
	int h,l,m0, m = 0, v = -key;

	h = 0;
	l = idx->idx_max;

	while (h != l)
	{
		m0 = m;
		m = (h + l) / 2;
		if (m0 == m) break;
		v = idx->key[m];

		if (v == key) break;
		if (v > key) l = m;
		if (v < key) h = m;
	}
	if (v != key) return -1;

	/* Move back to the first record with that key. */
	while (m > 0 && (idx->key[m -1] == key)) --m;

	/* Move forward until subkey matches */
	while (idx->subkey[m] != subkey && idx->key[m] == key) ++m;

	if (idx->key[m] != key) return -1;

	return m;
}


long lookup_advi(int key, int subkey)
{
	int m = lookupg(&advi, key, subkey);

	if (m >= 0) return ((advi.record[m] - 1) * 128) + 
                           ((advi.offset[m] - 1) * 2);
	return -1;
}


long lookup_advt(int key, int subkey)
{
	int m = lookupg(&advt, key, subkey);

	if (m >= 0) return ((advt.record[m] - 1) * 128) + 
                            (advt.offset[m] - 1);
	return -1;
}

/* Decode a word */
int getword(long offset)
{
	int wl, wh, dl, dh, k;

	fseek(fpadvi, offset, SEEK_SET);
	k = ((offset % 128) / 2) + 1;

	wl = fgetc(fpadvi);
	wh = fgetc(fpadvi);

	dl = ((wl ^ 0x75) - k) & 0xFF;
	dh = ((wh ^ 0x75) - k) & 0xFF;

	return dl + 256 * dh;
}

/* Decode a byte */
int getbyte(long offset)
{
        int wl, dl, k;

        fseek(fpadvt, offset, SEEK_SET);
        k = (offset % 128) + 1;

        wl = fgetc(fpadvt);

        dl = ((wl ^ 0x75) - k) & 0xFF;

        return dl;
}


/* Expand a Huffman-encoded string (version B03) */
void expand(int offset, int p)
{
	unsigned mask = 0x100;
	int node = 1;
	unsigned char ch, nv;
	int c, d = 0;

	while (node != 0)
	{
		if (mask > 0x80)
		{
			ch = getbyte(offset++);
			mask = 1;
		}
		if (ch & mask)
		{
			++node;
		} 
		if (node == 0)
		{
			printf("[Node 0 encountered]"); return;
		}
		nv = dec_dat[node - 1];
		node += (nv & 0x7F);

		if (nv & 0x80) 
		{
			c = dec_dat[node - 1];
			if (c == 0) return;
			if (!d && symtab && p)
			{
				if (c >= 1 && c <= ' ') putchar('/');
				else putchar(' ');
				d = 1;
			}
			putchar(c);
			node = 1;
		}
		mask = mask << 1;
	}
}


/* Output a string from ADVT.DAT */
void print_string(int offset, int p)
{
	int c, d;
	d = 0;

	if (huffman) 
	{
		expand(offset, p);
		return;
	}

	do
	{ 
		c = getbyte(offset++);
		if (!d && symtab && p)
		{
			if (c >= 1 && c <= ' ') putchar('/');
			else putchar(' ');
		}
		if (c) 
		{
			prbyte(c);
		}
		d = 1;
	} while(c);
}


/* Output a multiline string */
void say_string(int indent, int k, int sk, int finalcr)
{
	long offset;
	int zero = 1;

	putchar('"');
	while ( (offset = lookup_advt(k, sk)) >= 0)
	{
		if (!zero) printf("\n\t%*s", indent, "");
		print_string(offset, 0); 
		zero = 0;	
		++sk;	
	}
	putchar('"');
	if (finalcr) putchar('\n');
}


/* Read an argument from after an opcode */

#define ARG(x) { arg##x = arg(&w, &offset); }

int arg (int *w, int *offset)
{
	int a;

	(*w)++; 
	(*offset) += 2; 

	a = getword(*offset); 
	if (a >= 32768) a = 65536 - a;
	return a;
}

static int opc_indent;

void show_routine(int arg)
{
	if      (arg < 1000) fputs("INITIAL\t", stdout);
	else if (arg < 2000) fputs("XOBJECT\t", stdout);
	else if (arg < 3000) fputs("AT\t",      stdout);
	else if (arg < 5000) fputs("ACTION\t",  stdout);
	else if (arg < 6000) fputs("LABEL\t",   stdout);
	else if (arg < 7000) fputs("REPEAT\t",  stdout);
}

void show_txtid(int arg)
{
        if      (arg < 2000) fputs("OBJECT\t",  stdout);
        else if (arg < 3000) fputs("PLACE\t",   stdout);
        else if (arg < 5000) fputs("TEXT\t",    stdout);
}


void show_obj(int indent, int arg)
{
	char *s = sym_lookup(arg);

	if (arg < 1000 && indent)
	{
		printf("%d", arg);
		return;
	}

	if (symtab)
	{
		if (!indent) 
		{
			show_routine(arg);
			if (arg < 1000 || (arg >= 6000 && arg < 7000)) return;
		}
		if (s)
		{
			fputs(s, stdout);
			return;
		}
	}
	putchar('[');
	if (!indent) show_routine(arg);
	printf("%04d ", arg);
	if (arg >= 1000 && arg < 4000) 
	{
		if (!showsym(arg)) say_string(indent, arg, 0, 0);
	}
	if (arg >= 4000 && arg < 5000) say_string(indent, arg, 0, 0);
	if (arg >= 7000 && arg < 8000) showsym(arg);
	putchar(']');
}


void show_bis2(int arg1, int arg2)
{
	if ((arg1 >= 1000 && arg1 < 2000) || (arg1 >= 7000 && arg1 != 7016) ) switch(arg2)
	{
		case 0: fputs("PORTABLE",  stdout); break;
		case 2: fputs("VALUED",    stdout); break;
		case 3: fputs("SCHIZOID",  stdout); break;
		case 4: fputs("UNSTABLE",  stdout); break;
		case 5: fputs("MORTAL",    stdout); break;
		case 6: fputs("OPENABLE",  stdout); break;
		case 7: fputs("INVISIBLE", stdout); break;
		case 8: fputs("EDIBLE",    stdout); break;
		case 9: fputs("FREEBIE",   stdout); break;

		default: printf("%d", arg2); break;
	}
	else if (arg1 >= 2000 && arg1 < 3000) switch(arg2)
	{
                case 0: fputs("LIT",       stdout); break;
		case 2: fputs("NODWARF",   stdout); break;
		case 3: fputs("NOBACK",    stdout); break;
		case 4: fputs("NOTINCAVE", stdout); break;
		case 5: fputs("HINTABLE",  stdout); break;
		case 6: fputs("H20HERE",   stdout); break;
		case 7: fputs("INMAZE",    stdout); break;
		case 8: fputs("ONE.EXIT",  stdout); break;
                case 9: fputs("THROWER",   stdout); break;
		default: printf("%d", arg2); break;
	}
	else if (arg1 == 7016) switch(arg2)
	{
		case 0:   fputs("DEMO",     stdout); break;
		case 1:   fputs("QUICKIE",  stdout); break;
		case 2:   fputs("FASTMODE", stdout); break;
		case 3:   fputs("NOMAGIC",  stdout); break;
		case 4:   fputs("PANICED",  stdout); break;
		case 5:   fputs("OLORIN",   stdout); break;	
		default:  printf("%d", arg2);    break;
	}
	else printf("%d", arg2);
}

int show_opcode(int opc, int offset)
{
	int w = 1;
	int arg1, arg2, arg3;

	switch(opc)
	{
		case  1: ARG(1);
			 printf("\t%*sKEYWORD ", opc_indent, "");	
			 show_obj(opc_indent + 8, arg1);
			 putchar('\n');
			 break;
                case  2: ARG(1);
                         printf("\t%*sHAVE  ", opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar('\n');
                         break;
                case  3: ARG(1);
                         printf("\t%*sNEAR  ", opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar('\n');
                         break;

                case  4: ARG(1);
                         printf("\t%*sAT    ", opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar('\n');
                         break;
		case  5: ARG(1);
			 printf("\t%*sANYOF ", opc_indent, "");
			 show_obj(opc_indent + 6, arg1);
			 putchar('\n');
			 break;
		case  6: ARG(1);
                         ARG(2);
                         printf("\t%*sIFEQ  ",  opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar(',');
                         show_obj(opc_indent + 6, arg2);
                         putchar('\n');
                         ++opc_indent;
                         break;

		case  7: ARG(1);
			 ARG(2);
                         printf("\t%*sIFLT  ",  opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar(',');
                         show_obj(opc_indent + 6, arg2);
                         putchar('\n');

			 ++opc_indent;
			 break;

                case  8: ARG(1);
                         ARG(2);
                         printf("\t%*sIFGT  ",  opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar(',');
                         show_obj(opc_indent + 6, arg2);
                         putchar('\n');

                         ++opc_indent;
                         break;

		case 9:  ARG(1);
                         printf("\t%*sIFAT  ",  opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
			 ++opc_indent;	
			 putchar('\n');
			 break;
		case 10: ARG(1);
                         printf("\t%*sCHANCE ",  opc_indent, "");
                         show_obj(opc_indent + 7, arg1);
                         ++opc_indent;
			 putchar('\n');
                         break;

		case 11: if (opc_indent == 0) ++opc_indent;
			 printf("\t%*sELSE\n", opc_indent - 1, "");
			 break;
		case 12: if (opc_indent > 0) --opc_indent;
			 printf("\t%*sFIN\n", opc_indent, "");
			 break;
		case 13: opc_indent = 0;
                         printf("\t%*sEOF\n", opc_indent, "");
                         break;
                case 14: ARG(1)
                         printf("\t%*sGET   ", opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar('\n');
                         break;
                case 15: ARG(1)
                         printf("\t%*sDROP  ", opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar('\n');
                         break;
		case 16: ARG(1)
			 ARG(2)
			 printf("\t%*sAPPORT ", opc_indent, "");
			 show_obj(opc_indent + 8, arg1);
			 putchar(',');
			 show_obj(opc_indent + 8, arg2);
			 putchar('\n');
			 break;
		case 17: ARG(1)
			 ARG(2)
			 printf("\t%*sSET   ", opc_indent, "");
			 show_obj(opc_indent + 6, arg1);
			 putchar(',');
                         show_obj(opc_indent + 6, arg2);
			 putchar('\n');
			 break;
		case 18: ARG(1)
			 ARG(2)
                         printf("\t%*sADD   ",  opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar(',');
                         show_obj(opc_indent + 6, arg2);
                         putchar('\n');
			 break;
		case 19: ARG(1)
                         ARG(2)
                         printf("\t%*sSUB   ",  opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar(',');
                         show_obj(opc_indent + 6, arg2);
                         putchar('\n');
                         break;
		case 20: ARG(1)
			 printf("\t%*sGOTO  ", opc_indent, "");
			 show_obj(opc_indent + 6, arg1);
			 putchar('\n');
			 break;
		case 21: ARG(1)
			 ARG(2)
			 printf("\t%*sMOVE  ", opc_indent, "");
			 show_obj(6 + opc_indent, arg1);
			 putchar(',');
			 show_obj(6 + opc_indent, arg2);
			 putchar('\n'); 
			 break;
		case 22: ARG(1);
			 printf("\t%*sCALL  ", opc_indent, "");
                         show_obj(6 + opc_indent, arg1);
			 putchar('\n'); 
			 break;
		case 23: ARG(1)
			 printf("\t%*sSAY   ", opc_indent, "");
			 show_obj(6 + opc_indent, arg1);
			 putchar('\n');
			 break;
		case 24: ARG(1)
                         ARG(2)
                         printf("\t%*sNAME  ", opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar(',');
                         show_obj(opc_indent + 6, arg2);
                         putchar('\n');
                         break;

		case 25: ARG(1)
			 ARG(2)
			 printf("\t%*sVALUE ", opc_indent, "");
			 show_obj(6 + opc_indent, arg1);
			 putchar(',');
			 show_obj(6 + opc_indent, arg2);
			 putchar('\n');
			 break;
                case 26: printf("\t%*sPROCEED\n", opc_indent, "");
                         break;
		case 27: printf("\t%*sQUIT\n", opc_indent, "");
			 break;
		case 28: printf("\t%*sSTOP\n", opc_indent, "");
			 break;
		case 29: ARG(1);
			 printf("\t%*sIFHAVE ", opc_indent, "");
                         show_obj(7 + opc_indent, arg1);
                         putchar('\n');
			 ++opc_indent;
                         break;
                case 30: ARG(1);
                         printf("\t%*sIFNEAR ", opc_indent, "");
                         show_obj(7 + opc_indent, arg1);
                         putchar('\n');
			 ++opc_indent;
                         break;
		case 31: if (opc_indent > 0) --opc_indent;
			 printf("\t%*sOR\n", opc_indent - 1, "");
			 break;
		case 32: ARG(1)
			 ARG(2)
			 printf("\t%*sRANDOM ", opc_indent, "");
                         show_obj(7 + opc_indent, arg1);
			 putchar(',');
			 show_obj(7 + opc_indent, arg2);
			 putchar('\n');
			 break;
		case 33: ARG(1)
			 ARG(2)
                         printf("\t%*sBIT   ", opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar(',');
                         show_bis2(arg1, arg2);
		 	 ++opc_indent;
			 putchar('\n');
			 break;
		case 34: ARG(1);
			 ARG(2);
                         printf("\t%*sBIS   ", opc_indent, "");
			 show_obj(opc_indent + 6, arg1);
			 putchar(',');
			 show_bis2(arg1, arg2);
			 putchar('\n');
			 break;
                case 35: ARG(1);
                         ARG(2);
                         printf("\t%*sBIC   ", opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar(',');
                         show_bis2(arg1, arg2);
                         putchar('\n');
                         break;

		case 36: ARG(1);
			 printf("\t%*sITOBJ ", opc_indent, "");
			 show_obj(opc_indent + 6, arg1);
			 printf("\n");
			 ++opc_indent;
			 break;
                case 37: ARG(1);
                         printf("\t%*sITPLACE ", opc_indent, "");
                         show_obj(opc_indent + 8, arg1);
                         printf("\n");
                         ++opc_indent;
                         break;
		case 38: if (opc_indent) --opc_indent;
			 printf("\t%*sEOI\n", opc_indent, "");
			 break;
                case 39: ARG(1)
                         ARG(2)
                         printf("\t%*sIFLOC ", opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar(',');
                         show_obj(opc_indent + 6, arg2);
                         putchar('\n');
			 break;
		case 40: printf("\t%*sINPUT\n", opc_indent, "");
			 break;
		case 41: ARG(1)
                         ARG(2)
                         printf("\t%*sLOCATE  ", opc_indent, "");
                         show_obj(opc_indent + 8, arg1);
                         putchar(',');
                         show_obj(opc_indent + 8, arg2);
                         putchar('\n');
                         break;
		case 42: printf("\t%*sNOT\n", opc_indent - 1, "");
                         break;
                case 43: ARG(1);
                         printf("\t%*sIFKEY ", opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar('\n');
                         ++opc_indent;
			 break;
		case 44: ARG(1)
                         ARG(2)
                         printf("\t%*sLDA   ", opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar(',');
                         show_obj(opc_indent + 6, arg2);
                         putchar('\n');
                         break;
                case 45: ARG(1);
                         ARG(2);
			printf("\t%*sEVAL  ",  opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar(',');
                         show_obj(opc_indent + 6, arg2);
                         putchar('\n');
                         break;
		case 46: ARG(1)
                         ARG(2)
                         printf("\t%*sMULT  ",  opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar(',');
                         show_obj(opc_indent + 6, arg2);
                         putchar('\n');
                         break;
		case 47: ARG(1)
                         ARG(2)
                         printf("\t%*sDIV   ",  opc_indent, "");
                         show_obj(opc_indent + 6, arg1);
                         putchar(',');
                         show_obj(opc_indent + 6, arg2);
                         putchar('\n');
                         break;

                case 48: ARG(1);
                         ARG(2);
                         printf("\t%*sSVAR  %d,", opc_indent, "", arg1);
                         show_obj(6 + opc_indent, arg2);
			 putchar('\n');
                         break;

		case 49: ARG(1);
			 ARG(2);
			 printf("\t%*sEXEC  %d,", opc_indent, "", arg1);
                         show_obj(6 + opc_indent, arg2);
			 putchar('\n');
			 break;
		case 50: ARG(1)
			 printf("\t%*sQUERY ", opc_indent, "");
			 show_obj(8 + opc_indent, arg1);
			 putchar('\n');
			 ++opc_indent;
			 break;
		case 51: if (opc_indent > 0) --opc_indent;
                         printf("\t%*sAND\n", opc_indent - 1, "");
                         break;
		/* XOR not used in supplied ADV. */
                case 52: if (opc_indent > 0) --opc_indent;
                         printf("\t%*sXOR\n", opc_indent - 1, "");
                         break;

		case 53: ARG(1) 
			 ARG(2)
                         printf("\t%*sDEPOSIT ",  opc_indent, "");
                         show_obj(opc_indent + 8, arg1);
                         putchar(',');
                         show_obj(opc_indent + 8, arg2);
                         putchar('\n');
                         break;
		case 54: ARG(1)
                         printf("\t%*sITLIST  ", opc_indent, "");
                         show_obj(8 + opc_indent, arg1);
                         ++opc_indent;
			 break;
		case 55: ARG(1)
			 ARG(2)
			 ARG(3)
			 printf("\t%*sSMOVE ", opc_indent, "");
                         show_obj(6 + opc_indent, arg1);
                         putchar(',');
                         show_obj(6 + opc_indent, arg2);
			 putchar(',');
                         show_obj(6 + opc_indent, arg3);
                         putchar('\n');
			 break; 
                case 56: ARG(1);
                         printf("\t%*sDEFAULT ", opc_indent, "");
                         show_bis2(1001, arg1);
                         putchar('\n');
                         break;
			 
		default: printf("\t%*s%04x\n", opc_indent, "", opc);
	}

	return w;
}

#undef ARG


static void fancy_text(int key, int subkey, long offset)
{
	static int keylast = -1;
	static int sublast = -1;
	char *s;
	int n;
	int percent;

	if (keylast != key)	/* First one in this set */
	{
		show_txtid(key);
		s = sym_lookup(key);
		if (!s) printf("[%04d]\n", key);
		else puts(s);

		if (subkey) puts("\t>$< (subkey 0)");

		if (subkey > 10)
		{
			for (n = 10; n < subkey; n += 10)
				printf("\t%%>$< (subkey %d)\n", n);	
		}
		if (subkey) sublast = 0; 
		else	    sublast = -1;
	}
	else	/* Repeat business */
	{
		if (subkey - sublast > 10) 
			for (n = sublast; n < (subkey-10); n += 10)
			{
				printf("\t%%>$< (subkey %d)\n", n);
			}
	}
	putchar('\t');

	percent = 1;	/* Include percent sign */
	if (!subkey) percent = 0;
	if (subkey - sublast == 1) percent = 0;
	if (percent) putchar('%'); 
	
	if (percent || (subkey == 0)) print_string(offset, 0);		
	else			      print_string(offset, 1);

	keylast = key;
	sublast = subkey;
}
 


int main(int argc, char **argv)
{
	long offset;
	int n, w, x, y, s, z[3];

	FILE *fp = fopen("compress.dat", "rb");
	if (fp)
	{
		compressed = 1;
		fread(comp_dat, 1, 256, fp);
		fclose(fp);
	}
	else 
	{
		fp = fopen("decode.dat", "rb");
		if (fp)
		{
			huffman = 1;
			fread(dec_dat, 1, 512, fp);
			fclose(fp);
		}
	}
	if (!compressed && !huffman)
	{
		fprintf(stderr, "No COMPRESS.DAT or DECODE.DAT. "
				"No token expansion will be done.\n");
	}

	for (w = 1; w < argc; w++)
	{
		if      (!strcmp(argv[w], "-st")) nomsg = 1;
		else if (!strcmp(argv[w], "-ss")) nosym = 1;
		else if (!strcmp(argv[w], "-si")) noini = 1;	
		else if (!strcmp(argv[w], "-sr")) norep = 1;
		else if (!strcmp(argv[w], "-sa")) noact = 1;
		else if (!strcmp(argv[w], "-sl")) noloc = 1;
		else if (!strcmp(argv[w], "-sp")) noprc = 1;
		else if (!strcmp(argv[w], "-so")) noobj = 1;
		else if (!strcmp(argv[w], "-t"))  symtab = 1;	
		else 
		{
			printf("Option %s unrecognised.\n\n", argv[w]);
			printf("Options are :	\n"
                               " -si  Skip INITIAL routines\n"
			       " -so  Skip OBJECT  routines\n"
			       " -sl  Skip location-specific (AT) routines\n"
			       " -sa  Skip ACTION routines\n"
			       " -sp  Skip procedure (LABEL) routines\n"
			       " -sr  Skip REPEAT routines\n"
                               " -ss  Skip symbol table (vocabulary etc.)\n"
			       " -st  Skip game text dump\n"
			       " -t   Get as near to A-code source, using '%s'"
                               " as symbol list\n", SYMBOLFILE);
			return 0;
		}
		
	}

	fpadvi = fopen("advi.dat", "rb");
	fpadvt = fopen("advt.dat", "rb");
	if (!fpadvi || !fpadvt) 
	{
		if (fpadvi) { fclose(fpadvi); perror("advt.dat"); }
		else	    { fclose(fpadvt); perror("advi.dat"); }
		exit(1);
	}
	if (load_ptrfile(&advi, "advi.ptr")) exit(2);
	if (load_ptrfile(&advt, "advt.ptr")) exit(2);

	/* ADVI reader */
	offset = lookup_advi(9000, 0);
	if ((!nosym) && offset > 0)
	{
		w = getword(offset);	
		printf("Symbol table length=%d\n", w);

		offset = lookup_advi(9001, 0);
		for (x = 0; x < w; x++)
		{
			z[0] = getword(offset); offset += 2;
			z[1] = getword(offset); offset += 2;
			z[2] = getword(offset); offset += 2;
			y    = getword(offset); offset += 2;

		printf("%c%c%c%c%c%c %04d\n", 
					      (z[0] & 0xFF), (z[0] >> 8),
				              (z[1] & 0xFF), (z[1] >> 8),
                                              (z[2] & 0xFF), (z[2] >> 8), y );	
		}
		printf("-- \n");
	}
	for (n = 0; n < advi.idx_max; n++)
	{
		x = advi.key[n];
		if (x >= 0    && x < 1000 && noini) continue;
		if (x >= 1000 && x < 2000 && noobj) continue;
		if (x >= 2000 && x < 3000 && noloc) continue;
		if (x >= 3000 && x < 4000 && noact) continue;
		if (x >= 5000 && x < 6000 && noprc) continue;
		if (x >= 6000 && x < 7000 && norep) continue;
		if (x >= 9000) break;	/* Handled separately */
		s = advi.subkey[n];	/* Subkey 	 */
                if (s == -1 || s == 0xFFFF) break;
	
		offset = lookup_advi(x, s);
		if (offset >= 0)
		{
			int c, d;
			d = getword(offset); offset += 2;

			show_obj(0, x); 
			if (symtab) putchar('\n');
			else printf(" SUB=%03d  LEN=%04d: \n", s, d);
			opc_indent = 0;
			while (d > 0)	
			{
				c = getword(offset); 

				y = show_opcode(c, offset);
				d -= y;	
				offset += 2 * y; 
			}
			printf("\n");
		}
	}

	/* ADVT reader */
	if (!nomsg) for (n = 0; n < advt.idx_max; n++)
	{
		x = advt.key[n];
		s = advt.subkey[n];
		
		if (s == -1 || s == 0xFFFF) break;
	
		offset = lookup_advt(x, s);
		if (offset >= 0)
		{
			if (symtab)
			{
				fancy_text(x, s, offset);	
			}
			else 
			{
				printf("%04d,%03d: ", x, s);
				print_string(offset, 0);
			}
			printf("\n");
		}
	}

	fclose(fpadvi);
	fclose(fpadvt);

	free(advi.idxdat);
	free(advt.idxdat);

	for (n = 0; n < MAXSYM; n++)
	{
		if (symbols[n]) free(symbols[n]);
	}

	return 0;
}

/* Look up a symbol in external symbol table (used to produce usable A-code
 * rather than numeric dumps) */


static char *sym_lookup(int symbol)
{
	char symbuf[80], *t;
	int n;

	if (!symtab) return NULL;	/* Symbol table disabled */

	if (!symcount)			/* Symbols not loaded */
	{
		FILE *fp = fopen(SYMBOLFILE, "r");
		if (!fp)
		{
			symtab = 0;	
			perror("symbol.tab");
			return NULL;
		}
		while(fgets(symbuf, 79, fp))
		{
			symbuf[79] = 0;
			t = strchr(symbuf, '#');	/* Remove comments */
			if (t) *t = 0;
			t = strchr(symbuf, '\t');	/* 1st tab */
			if (t) t = strchr(t+1, '\t');	/* 2nd tab */
			if (t) *t = 0;	
			t = strrchr(symbuf, '\n');	/* Strip off crs */
			if (t) *t = 0;
			t = strchr(symbuf, ' ');
			if (t) *t = 0;			/* Trailing spaces */
			n = atoi(symbuf); 
			t = strchr(symbuf, '\t');	
			if (!t) continue;
			++t;
			if (!n || n >= MAXSYM) continue;

			if (symbols[n]) 
			{
				fprintf(stderr, "Warning: Symbol %s is a "
				        "synonym - ignored\n", t);
				continue;
			}
			symbols[n] = malloc(1 + strlen(t));
			if (symbols[n])
			{
				++symcount;
				strcpy(symbols[n], t);
			}
		}		
		fclose(fp);
		if (!symcount)
		{
			symtab = 0;
			fprintf(stderr, "%s: no symbols loaded\n", SYMBOLFILE);
		}
	}
	return symbols[symbol];
}
