/*
	Copyright (C) 2014 2015 Johan Mattsson

	This library is free software; you can redistribute it and/or modify 
	it under the terms of the GNU Lesser General Public License as 
	published by the Free Software Foundation; either version 3 of the 
	License, or (at your option) any later version.

	This library is distributed in the hope that it will be useful, but 
	WITHOUT ANY WARRANTY; without even the implied warranty of 
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
	Lesser General Public License for more details.
*/

using Cairo;
using B;

namespace BirdFont {
	public class SubMenu : GLib.Object { 
		public Gee.ArrayList<MenuItem> items;
		
		public SubMenu () {
			items = new Gee.ArrayList<MenuItem> ();
		}
	}
}
