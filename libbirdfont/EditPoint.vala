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

using Math;

namespace BirdFont {

public enum PointType {
	NONE,
	LINE_QUADRATIC,      // line with quadratic handle
	LINE_DOUBLE_CURVE,   // line with two quadratic handles
	LINE_CUBIC,          // line with cubic handles
	CUBIC,
	DOUBLE_CURVE,        // two quadratic points with a hidden point half way between the two line handles
	QUADRATIC,
	HIDDEN,
	FLOATING,
	END
}

public class EditPoint : GLib.Object {
	
	public double x;
	public double y;
	public PointType type;
	
	public unowned EditPoint? prev = null;
	public unowned EditPoint? next = null;

	public static const uint NONE = 0;
	public static const uint ACTIVE = 1;
	public static const uint SELECTED = 1 << 1;
	public static const uint DELETED_POINT = 1 << 2;
	public static const uint TIE = 1 << 3;
	public static const uint REFLECTIVE = 1 << 4;
	
	public static const uint INTERSECTION = 1 << 5;
	public static const uint NEW_CORNER = 1 << 6;
	public static const uint STROKE_OFFSET = 1 << 7;
	public static const uint COUNTER_TO_OUTLINE = 1 << 8;
	public static const uint COPIED = 1 << 9;
	public static const uint REMOVE_PART = 1 << 10;
	public static const uint OVERLAY = 1 << 11;
	public static const uint CURVE = 1 << 12;
	public static const uint CURVE_KEEP = 1 << 13;
	public static const uint SEGMENT_END = 1 << 14;
	public static const uint SPLIT_POINT = 1 << 15;
	public static const uint SELF_INTERSECTION = 1 << 16;
	public static const uint COPIED_SELF_INTERSECTION = 1 << 17;
	
	public uint flags = NONE;
	
	public bool active_point {
		get {
			return (flags & ACTIVE) > 0;
		}
		
		set {
			if (value) {
				flags |= ACTIVE;
			} else {
				flags &= ~ACTIVE;
			}
		}	
	}
	
	public bool selected_point {
		get {
			return (flags & SELECTED) > 0;
		}
		
		set {
			if (value) {
				flags |= SELECTED;
			} else {
				flags &= ~SELECTED;
			}
		}	
	}
	
	public bool deleted {
		get {
			return (flags & DELETED_POINT) > 0;
		}
		
		set {
			if (value) {
				flags |= DELETED_POINT;
			} else {
				flags &= ~DELETED_POINT;
			}
		}	
	}

	public bool tie_handles {
		get {
			return (flags & TIE) > 0;
		}
		
		set {
			if (value) {
				flags |= TIE;
			} else {
				flags &= ~TIE;
			}
		}	
	}

	public bool reflective_point {
		get {
			return (flags & REFLECTIVE) > 0;
		}
		
		set {
			if (value) {
				flags |= REFLECTIVE;
			} else {
				flags &= ~REFLECTIVE;
			}
		}	
	}
			
	public int selected_handle = 0;
	
	public EditPointHandle right_handle;
	public EditPointHandle left_handle;

	/** Set new position for control point without moving handles. */
	public double independent_x {
		get { 
			return x;
		}
		
		set { 
			double d = value - x;
			x = value;
			right_handle.independent_x -= d;
			left_handle.independent_x -= d;
		}
	}

	public double independent_y {
		get {
			return y;	
		}
		
		set { 
			double d = value - y;
			y = value;
			right_handle.independent_y -= d;
			left_handle.independent_y -= d;
		}
	}
	
	public Color? color = null;

	public EditPoint (double nx = 0, double ny = 0, PointType nt = PointType.NONE) {	
		x = nx;
		y = ny;
		type = nt;
		right_handle = new EditPointHandle (this, 0, 7);
		left_handle = new EditPointHandle (this, PI, 7);	
	}
	
	public EditPoint.full (double nx = 0, double ny = 0, PointType nt = PointType.NONE) {
		x = nx;
		y = ny;
		type = nt;
		active_point = true;
		
		if (nt == PointType.FLOATING) {
			active_point = false;
		}
	
		right_handle = new EditPointHandle (this, 0, 7);
		left_handle = new EditPointHandle (this, PI, 7);

		if (unlikely (nx.is_nan () || ny.is_nan ())) {
			warning (@"Invalid point at ($nx,$ny).");
			x = 0;
			y = 0;
		}		
	}
	
	public bool is_valid () {
		return is_valid_position (x, y);
	}

	public static bool is_valid_position (double x, double y) {
		return likely (x.is_finite () && y.is_finite () 
			&& x > Glyph.CANVAS_MIN && x < Glyph.CANVAS_MAX
			&& y > Glyph.CANVAS_MIN && y < Glyph.CANVAS_MAX);
	}

	public void set_point_type (PointType t) {
		type = t;
	}
		
	public bool equals (EditPoint e) {
		return e.x == x 
			&& e.y == y 
			&& get_right_handle ().x == e.get_right_handle ().x
			&& get_right_handle ().y == e.get_right_handle ().y
			&& get_left_handle ().x == e.get_left_handle ().x
			&& get_left_handle ().y == e.get_left_handle ().y;
	}

	/** Make handles symmetrical. */
	public void set_reflective_handles (bool symmetrical) {
		reflective_point = symmetrical;
		
		if (symmetrical) {
			get_left_handle ().convert_to_curve ();
			get_right_handle ().convert_to_curve ();
			process_tied_handle ();
		}
	}

	/** Flip handles if next point on path is in the other direction. 
	 *  Used to recalculate handles after new point is inserted on a path.
	 */
	public void recalculate_handles (double px, double py) {
		double dr, dl;
		EditPointHandle t;
		
		if (next == null || get_next ().next != null) {
				return;
		}

		if (unlikely (reflective_point || tie_handles)) {
			warning ("Points on lines can't have tied handles.");
			return;
		}
		
		px = get_next ().get_next ().x;
		py = get_next ().get_next ().y;
		
		dr = Math.sqrt (Math.pow (px - right_handle.x, 2) + Math.pow (py - right_handle.y, 2));
		dl = Math.sqrt (Math.pow (px - left_handle.x, 2) + Math.pow (py - left_handle.y, 2));

		// flip handles
		if (dl < dr) {
			t = right_handle;
			right_handle = left_handle;
			left_handle = t;
		}		
	}
		
	public bool is_clockwise () {
		return get_direction () >= 0;
	}
	
	public double get_direction () {
		if (prev == null) {
			return 0;
		}
		
		return (x - get_prev ().x) * (y + get_prev ().y);
	}
	
	public void set_tie_handle (bool tie) {
		tie_handles = tie;
	}
	
	public void to_curve () {
		convert_from_line_to_curve (get_right_handle ());
		convert_from_line_to_curve (get_left_handle ());
	}
	
	public static void convert_from_line_to_curve (EditPointHandle h) {
		switch (h.type) {
			case PointType.LINE_QUADRATIC:
				h.type = PointType.QUADRATIC;
				break;
			case PointType.LINE_DOUBLE_CURVE:
				h.type = PointType.DOUBLE_CURVE;
				break;
			case PointType.LINE_CUBIC:
				h.type = PointType.CUBIC;
				break;
			default:
				break;
		}
	}

	public void process_tied_handle () 
	requires (next != null && prev != null) {
		double a, b, c, length, angle;
		EditPointHandle eh;
		EditPointHandle prev_rh, next_lh;
		
		eh = right_handle;
		
		a = left_handle.x - right_handle.x;
		b = left_handle.y - right_handle.y;
		c = a * a + b * b;
		
		if (c == 0) {
			return;
		}
		
		length = sqrt (fabs (c));
		
		if (right_handle.y < left_handle.y) {
			angle = acos (a / length) + PI;
		} else {
			angle = -acos (a / length) + PI;
		}
		
		prev_rh = get_prev ().get_right_handle ();
		next_lh = get_next ().get_left_handle ();	
		
		convert_from_line_to_curve (next_lh);
		convert_from_line_to_curve (prev_rh);
		convert_from_line_to_curve (left_handle);
		convert_from_line_to_curve (right_handle);	
		
		right_handle.angle = angle;
		left_handle.angle = angle - PI;

		set_tie_handle (true);
		eh.move_to_coordinate (right_handle.x, right_handle.y);
	}

	public EditPoint copy () {
		EditPoint new_point = new EditPoint ();
		
		new_point.x = x;
		new_point.y = y;
		
		new_point.type = type;
		new_point.flags = flags;

		new_point.right_handle.angle = right_handle.angle;
		new_point.right_handle.length = right_handle.length;
		new_point.right_handle.type = right_handle.type;

		new_point.left_handle.angle = left_handle.angle;
		new_point.left_handle.length = left_handle.length;		
		new_point.left_handle.type = left_handle.type;
		
		new_point.color = color;
		
		return new_point;
	}

	public double get_distance (double x, double y) {
		return Path.distance (this.x, x, this.y, y);
	}

	public unowned EditPointHandle get_left_handle () {
		if (unlikely (is_null (left_handle))) {
			warning ("EditPoint.left_handle is null");
		}
		
		return left_handle;
	}
	
	public unowned EditPointHandle get_right_handle () {
		if (unlikely (is_null (right_handle))) {
			warning ("EditPoint.right_handle is null");
		}
		
		return right_handle;
	}
	
	public unowned EditPoint get_prev () {
		if (unlikely (prev == null)) {
			warning ("EditPoint.prev is null");
		}
		
		return (!) prev;
	}

	public unowned EditPoint get_next () {
		if (unlikely (next == null)) {
			warning ("EditPoint.next is null");
		}
		
		return (!) next;
	}
	
	public unowned EditPoint get_link_item () {
		return this;
	}
	
	public void set_independet_position (double tx, double ty) {
		double rx, ry, lx, ly;
		
		rx = right_handle.x;
		ry = right_handle.y;

		lx = left_handle.x;
		ly = left_handle.y;
				
		set_position (tx, ty);
		
		left_handle.move_to_coordinate (lx, ly);
		right_handle.move_to_coordinate (rx, ry);
	}
		
	public void set_position (double tx, double ty) {
		EditPoint p, n;
		
		x = tx;
		y = ty;
		
		if (unlikely (tx.is_nan () || ty.is_nan ())) {
			warning (@"Invalid point at ($tx,$ty).");
			x = 0;
			y = 0;
		}
		
		// move connected quadratic handle
		if (right_handle.type == PointType.QUADRATIC) {
			if (next != null) {
				n = get_next ();
				n.set_tie_handle (false);
				n.set_reflective_handles (false);
				n.left_handle.move_to_coordinate_internal (right_handle.x, right_handle.y);
			}
		}
		
		if (left_handle.type == PointType.QUADRATIC) {
			if (prev != null && !get_prev ().is_selected ()) {
				p = get_prev ();
				p.set_tie_handle (false);
				p.set_reflective_handles (false);
				p.right_handle.move_to_coordinate (left_handle.x, left_handle.y);
			}
		}
	}
	
	public static void to_coordinate (ref double x, ref double y) {
		double xc, yc, xt, yt, ivz;
		Glyph g = MainWindow.get_current_glyph ();
		
		ivz = 1 / g.view_zoom;
		
		xc = g.allocation.width / 2.0;
		yc = g.allocation.height / 2.0;
				
		x *= ivz;
		y *= ivz;

		xt = x - xc + g.view_offset_x;
		yt = yc - y - g.view_offset_y;		
		
		x = xt;
		y = yt;
	}
	
	public bool is_selected () {
		return selected_point;
	}
	
	public void set_selected (bool s) {
		selected_point = s;
	}
	
	public bool set_active (bool active) {
		bool update = (this.active_point != active);
		
		if (update) {
			this.active_point = active;
		}
		
		return update;
	}

	public void convert_to_line () {
		left_handle.convert_to_line ();
		right_handle.convert_to_line ();		
	}

	public void convert_to_curve () {
		left_handle.convert_to_curve ();
		right_handle.convert_to_curve ();		
	}
			
	public string to_string () {
		StringBuilder s = new StringBuilder ();
		
		if (deleted) {
			s.append (@"Deleted ");
		}
		
		s.append (@"Control point: $x, $y\n");
		s.append (@"Left handle: angle: $(left_handle.angle) l: $(left_handle.length)\n");
		s.append (@"Right handle: angle: $(right_handle.angle) l: $(right_handle.length)\n");
		s.append (@"Type: $type Left: $(left_handle.type) Right: $(right_handle.type)\n".replace ("BIRD_FONT_POINT_TYPE_", ""));
		s.append (@"Flags $(flags)\n");
		
		return s.str;
	}
}

}
