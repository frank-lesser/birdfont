/*
	Copyright (C) 2012 2013 2014 2015 Johan Mattsson

	This library is free software; you can redistribute it and/or modify 
	it under the terms of the GNU Lesser General Public License as 
	published by the Free Software Foundation; either version 3 of the 
	License, or (at your option) any later version.

	This library is distributed in the hope that it will be useful, but 
	WITHOUT ANY WARRANTY; without even the implied warranty of 
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
	Lesser General Public License for more details.
*/

namespace BirdFont {

/** Format 12 cmap subtable */
public class CmapSubtableFormat12 : CmapSubtable {
	
	FontData cmap_data;
	
	public CmapSubtableFormat12 () {
	}

	public override ushort get_platform () {
		return 3;
	}

	public override ushort get_encoding () {
		return 10;
	}

	public override FontData get_cmap_data () {
		return cmap_data;
	}
	
	public override void generate_cmap_data (GlyfTable glyf_table) throws GLib.Error {
		GlyphRange glyph_range = new GlyphRange ();
		Gee.ArrayList<UniRange> ranges;
		FontData fd = new FontData ();
		uint32 first_assigned;
		uint32 index;
		
		first_assigned = 1;
		
		foreach (GlyphCollection g in glyf_table.glyphs) {
			if (!g.is_unassigned () && g.get_unicode_character () < 0xFFFFFFFF) {
				glyph_range.add_single (g.get_unicode_character ());
			}
		}
		
		ranges = glyph_range.get_ranges ();
		
		fd.add_u16 (12); // Format
		fd.add_u16 (0); // Reserved
		
		fd.add_u32 (16 + ranges.size * 12); // length
		
		fd.add_u32 (0); // Language
		fd.add_u32 ((uint32) ranges.size); // Number of groupings
		
		index = first_assigned;
		foreach (UniRange u in ranges) {
			
			if (u.start >= 0xFFFFFFFF || u.stop >= 0xFFFFFFFF) {
				warning ("Glyph range not supported by CmapSubtableFormat12.");
			} else {
				fd.add_u32 (u.start);
				fd.add_u32 (u.stop);
				fd.add_u32 (index);
				
				index += u.length ();
			}
		}
		
		cmap_data = fd;
	}
}

}
