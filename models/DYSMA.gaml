/**
* Name: Imagevectorization
* Based on the internal skeleton template. 
* Author: admin_ptaillandie
* Tags: 
*/

model Imagevectorization

global {
	file zone_shp <-shape_file("../results/buildings.shp");
	geometry shape <- envelope(zone_shp);
	
	string path_object <- "../generated/objects/" parameter: "Path to the object folder";
	string path_color_type <- "../generated/color_type.shp" parameter: "Path to the color type file";
	float shape_simplification <- 5.0 parameter: "Distance used for the simplification of shapes";
	float size_square <- 1.0 parameter: "Size of squares used for the vectorization";
	float min_area <- 100.0 parameter: "Mininimal area to keep an object";
	
	float environemnt_width <- shape.width;//2 #km parameter: "Width of the environment";
	float environemnt_height <-shape.height;// 2 #km parameter: "Height of the environment";
	pair<int,int> resolution <- 640::480 among:  [176::144,320::240,640::480, 1920::1080].pairs ;
	float max_area_envelope_coeff <- 0.80;
	float coeff_distance_world_contour <- 0.01;
	float coeff_binary <- 1.2 parameter: "Coefficint used to build the binary image; default = 1.0, higher than 1.0 = more tolerant";
	bool load_data_at_init <- false parameter: "Load the data and vectorize the image at the initizalisation"; 
	image_file drawing_file <- image_file("../images/webcamImage.png");
	
	matrix image_without_distorsion;
	point mouse_location;
	bool define_environment <- false;
	bool define_color_type <- false;
	bool define_empty_color_type <- false;
	string current_mode <- "";
	list<point> distorsion_points <-  [{175.0804443359375,212.2619171142578,0.0},{1789.93798828125,228.9404296875,0.0},{1758.2911376953125,1699.43603515625,0.0},{161.76394653320312,1681.14208984375,0.0}];
	geometry envrionment_shape <- polygon(distorsion_points);
	string geom_polygon <- "polygon" const: true;
	string geom_line <- "line" const: true;
	string geom_raw <- "raw" const: true;
		//image to display 
	matrix img_webcam; 
	matrix img_binary;
	webcam cam <- webcam(0);  
	
	map<string, matrix<int>> mats;
	
//geometry shape <- envelope(environemnt_width, environemnt_height);
	
	
	init {
		if load_data_at_init {
			if (length(distorsion_points) = 4) {
				image_without_distorsion <- remove_perspective( drawing_file.contents, distorsion_points);
			}
			do load_color_types;
			do vectorizing_image;
		} else {
			distorsion_points <- [];
			 envrionment_shape <-nil;
		}
		
	 environemnt_width <- world.shape.width;//2 #km parameter: "Width of the environment";
	environemnt_height <-world.shape.height;
		
	}
	
	action info_color {
		int w <- image_without_distorsion.columns;
			int h <- image_without_distorsion.rows;
			point pt <- #user_location;
			int c <- int(pt.x / environemnt_width * w) ;
			int r <- int(pt.y / environemnt_height * h) ;
			if (c >= 0) and (c < image_without_distorsion.columns) and (r >= 0) and (r < image_without_distorsion.rows) {
				rgb col <- rgb(image_without_distorsion[c,r]);
				color_type t<- world.closest_class(col);
				write sample(col) + " -> " + (t = nil ? "RIEN" : t.name); 
			}
	}
	action vectorizing_image {
		current_mode <- "Vectorizing";
		write "**** START THE VECTORIZATION ****";
	
		ask item {
			do die;
		}
		ask object {
			do die;
		}
		
		if not empty(color_type) {
			img_binary <- to_binary_image( image_without_distorsion,coeff_binary);
			int black <- int(#black);
			int white <- int(#white);
			
			int w <- image_without_distorsion.columns;
			int h <- image_without_distorsion.rows;
			write sample(w) + " " + sample(h) + " " + sample(img_binary.columns) + " " + sample(img_binary.rows);
			map<string, list<pair<int,int>>> per_type <- color_type as_map (each.name ::[]);
			loop i from: 0 to: 	w -1 {
				loop j from: 0 to: h -1 {
					if img_binary[i,j] = white {
						color_type t <- closest_class(rgb(image_without_distorsion[i,j]));
						
						if t != nil and !t.isEmpty {
							per_type[t.name]<<i::j;
						} 
						
					}
					
				} 
			}
			write "fin creation item";
			
			loop c over: per_type.keys {
				list<pair<int,int>> pixels <- per_type[c];
				
				if not empty(pixels) {
					 matrix<int> mat <- {w,h} matrix_with black;
					loop p over: pixels {
						mat[p.key, p.value] <- white;
					}
					
					 mats[c] <- mat;
				
					list<geometry> lines <- vectorize(mat);
					
					if not empty(lines) {
						loop l over: lines {
							geometry g <- nil;	
							if ( l overlaps world.shape.contour){
								 g <- l - (world.shape.contour +  (world.shape.width * coeff_distance_world_contour));
								if g != nil {
									g <- polygon(g.points);
										
									if g.area > polygon(l.points).area {
										g <-  polygon(l.points);
									}
								}										
							} else {
								g <- (polygon(l.points)) simplification shape_simplification;
							}
							if g != nil and envelope(g).area < (world.shape.area * max_area_envelope_coeff ){
								loop gg over: g.geometries {
									if gg.area >= min_area {
										create object with:(shape:g , type:(color_type first_with (each.name = c)), type_name:c) ;
									}	
								}
							}
						}
					}
				}
			}
			
			ask object sort_by (- each.shape.area) {
				ask object overlapping self {
					if (myself.type = type) {
						geometry it <- myself inter self;
						if (it.area/shape.area > 0.3) {
							do die;
						}
					}
				}
			}
			
			ask object {
				switch type.geom_type {
					match geom_polygon {
						shape <- solid(shape);
					}
					match geom_line {
						shape <- solid(shape).contour;
					}
				}
				
			}
		}	
		write "**** END OF THE VECTORIZATION ****";
		current_mode <- "";
		
	}

	
	color_type closest_class(rgb c) {
			
		float distMin <- #max_float;
		color_type sc <- nil;
		loop t over: color_type {
			list<float> hsb <- list<float> (to_hsb(c));
			
			//int dist <- abs(c.red - t.color.red) + abs(c.green - t.color.green) + abs(c.blue - t.color.blue) ;
			float dist <- abs(hsb[0] - t.h) + abs(hsb[1] - t.s) + abs(hsb[2] - t.b);//sqrt((c.red - t.color.red)^2 + (c.green - t.color.green)^2 + (c.blue - t.color.blue)^2) ;
			
			if dist < distMin {
				distMin <- dist;
				sc <- t;
				
			} 
		} 
		if distMin <= 100 {
			return sc;
		}
		return nil;
		
	}
	
	reflex update_webcam {
		img_webcam <- cam_shot(cam, resolution, false, false, false);	
	}
	
	action save_image {
		save img_webcam format: image to: "../generated/webcamImage.png";
		drawing_file <- image_file("../generated/webcamImage.png");
		write "image saved in generated";
	}
	
	action save_objects {
		loop type over: color_type {
			list<object> objs <- object where (each.type = type);
			if not empty(objs) {
				save objs format: shp to: path_object + type.name + ".shp";
			}
		}
		write "objects saved in "+ path_object;
	}
	action define_empty_color_type {
		define_empty_color_type <- not define_empty_color_type;
		if define_empty_color_type {
			define_color_type <- false;
			define_environment <- false;
			current_mode <- "define empty color type";
		} else {
			current_mode <- "";
		}
		write "empty color defined";
	}
	action define_color_type {
		define_color_type <- not define_color_type;
		if define_color_type {
			define_environment <- false;
			define_empty_color_type <- false;
			current_mode <- "define color type";
		} else {
			current_mode <- "";
		}
		write "type color defined";
	}
	
	action activate_desactivate_webcam {
		if paused {
			do resume;
		} else {
			do pause;
		}
	}
	
	action define_environment_points {
		define_environment <- not define_environment;
		if (define_environment) {
			distorsion_points <- []; 
			envrionment_shape <- nil;
			define_empty_color_type <- false;
			define_color_type <- false;
			
			current_mode <- "define environment";
		} else {
			current_mode <- "";
		}
		write "environment defined";
	}
	
	action select_color_type {
		color_type c <- first(color_type overlapping #user_location);
		if c != nil {
			bool delete <- user_confirm("Delete a color type", "Delete the " + c.name + " color type?");
			if delete {
				ask c {do die;}
				int cpt <- 0;
				ask color_type {
					location <- {20 #px, (1 + cpt) * 50 #px}; 
					cpt <- cpt + 1;
				}
			}
		}
		ask item {
			do die;
		}
	}
	
	action reset_color_types {
		ask color_type {
			do die;
		}
		write "color reseted";
	}
	action load_color_types {
		do reset_color_types;
		int cpt <- 0;
		create color_type from: file(path_color_type) with: (name::get("name"), color::get("color"), geom_type::get("geom_type")) {
			location <- {20 #px, (1 + cpt) * 50 #px}; 
			
			cpt <- cpt + 1;
		}
			write "color loaded";
	}
	
	action save_types {
		save color_type format: shp to: path_color_type attributes: ["name", "color", "geom_type"];
	write "save type";
	}
	action define_mouse_loc {
		mouse_location <- #user_location;
	}
	
	action mouse_click {
			
		if define_environment {
			if (length(distorsion_points) < 4) {
				distorsion_points << #user_location;
				if length(distorsion_points) >= 3 {
					envrionment_shape <- polygon(distorsion_points);
					if length(distorsion_points) = 4{
						write sample(distorsion_points);
						 envrionment_shape <- polygon(distorsion_points);
						image_without_distorsion <- remove_perspective( drawing_file.contents, distorsion_points);
						ask experiment {
							do update_outputs(true);
						}
					}
				}
			}
		} else if define_color_type {
			int w <- drawing_file.contents.columns;
			int h <- drawing_file.contents.rows;
			point pt <- #user_location;
			int c <- int(pt.x / environemnt_width * w) ;
			int r <- int(pt.y / environemnt_height * h) ;
			if (c >= 0) and (c < drawing_file.contents.columns) and (r >= 0) and (r < drawing_file.contents.rows) {
				rgb col <- rgb(drawing_file.contents[c,r]);
				map  result <- user_input_dialog("Type associated to this color",[choose("Type name", string, "digue", ["digue","barrage","bassin","delocalisation"]), enter("Color", col ), choose("Geometry type", string, geom_polygon, [geom_polygon,geom_line,geom_raw]) ]);
				
				string n <- string(result["Type name"]);
				col <- rgb(result["Color"]);
				create color_type with: (color:col, name:n, location : {20 #px, (1 + length(color_type)) * 50 #px}, geom_type : string(result["Geometry type"]));
			}
		}  else if define_empty_color_type {
			int w <- drawing_file.contents.columns;
			int h <- drawing_file.contents.rows;
			point pt <- #user_location;
			int c <- int(pt.x / environemnt_width * w) ;
			int r <- int(pt.y / environemnt_height * h) ;
			if (c >= 0) and (c < drawing_file.contents.columns) and (r >= 0) and (r < drawing_file.contents.rows) {
				rgb col <- rgb(drawing_file.contents[c,r]);
				create color_type with:(	color: col,	name:"Empty", location : {20 #px, (1 + length(color_type)) * 50 #px}); 
			}
		}
	}
}

species object {
	color_type type;
	string type_name;
	aspect default {
		draw shape + 5 color: type.color;
		//draw shape.contour color: #black depth: 10;
	}
}
species item {
	color_type type;
	geometry shape <- square(size_square);
	aspect default {
		draw shape color: type.color;
	}
}

species color_type {
	bool isEmpty <-false;
	float h;
	float s;
	float b;
	rgb color;
	string geom_type <- "polygon";
	
	init {
		shape <- rectangle(500 #px, 40 #px);
		isEmpty <-name ="Empty";
		list<float> hsb <- list<float>(to_hsb(color));
		h <- hsb[0];
		s <- hsb[1];
		b <- hsb[2];
		
	}
	aspect default {
		draw square(10 #px) color: color;
		draw name at: location + {20 #px, 0} anchor: #left_center color: color;
	}
}

experiment Imagevectorization type: gui {
	parameter "Path to the object folder" var:path_object  ;
	parameter "Path to the color type file" var:path_color_type  ;
	parameter "Distance used for the simplification of shapes" var:shape_simplification  ;
	parameter "Size of squares used for the vectorization" var:size_square  ;
	parameter "Mininmal area to keep an object" var:min_area  ;
	
	parameter "Width of the environment" var:environemnt_width  ;
	parameter "Height of the environment" var:environemnt_height  ;
	
	
	output {
		 layout horizontal([0::6000,vertical([1::5000,2::5000])::5000]) tabs:true editors: false;
		
		display image type: 3d  axes: false{
			overlay position: { 5, 5 } size: { 800 #px, 180 #px } background: # black transparency: 0.4 border: #black rounded: true
            {
            	draw "current action: " + current_mode at: { 50#px,  30#px } color: # white font: font("Helvetica", 30, #bold);
            	draw "'v': vectorizing image" at: { 50#px,  60#px } color: # white font: font("Helvetica", 20, #bold);
            	
            	draw "'b': define the environment points" at: { 50#px,  80#px } color: # white font: font("Helvetica", 20, #bold);
            	draw "'c': define a new color type" at: { 50#px,  100#px } color: # white font: font("Helvetica", 20, #bold);
            	draw "'e': define the empty color type" at: { 50#px,  120#px } color: # white font: font("Helvetica", 20, #bold);
            	draw "'s': save the created objects" at: { 50#px,  140#px } color: # white font: font("Helvetica", 20, #bold);
            }
			image drawing_file refresh: true ;
			event "v" action: vectorizing_image;
			event "b" action: define_environment_points;
			event "c" action: define_color_type;
			event "e" action: define_empty_color_type;
			event "s" action: save_objects;
			
			event #mouse_move action: define_mouse_loc;
			event #mouse_down action: mouse_click;
			graphics "mouse_loc" {
				draw circle(5) at: mouse_location;
			}
			graphics "Environment" transparency: 0.6{
				if envrionment_shape != nil {
					draw envrionment_shape color: #red;
				}
				loop pt over: distorsion_points {
					draw circle(10) color: #red at: pt;
				}
			}
		}
		
		display "Image without distorsion"  {
			
				image image(image_without_distorsion) ;
				
				species object;
				event #mouse_down action: info_color;
				event #mouse_move action: define_mouse_loc;
			
				graphics "mouse_loc" {
					draw circle(5) depth: 1.0 at: mouse_location;
				}
			
		}
		
		display "Binary_image_themes"  type: 3d {
				graphics "binary images per themes" {
					int nb_rows <- 1+ int(length(mats)/2);
					int nb_columns <- 1+ int(length(mats)/nb_rows);
					int cpt <- 0;
					list<geometry> rects <- to_rectangles(world.shape, nb_columns, nb_rows);
					//image matrix:img_binary;
					loop theme over: mats.keys {
						geometry rect <- rects[cpt] ;
						draw rect* 0.9 texture: image(mats[theme]);
						draw theme size: 10 color: #red at: {rect.location.x, min(rect.points collect each.y) + rect.height*0.1, 2} ;
						cpt <- cpt + 1; 
						
					}
				}
				
		}
	
		
		display "Binary image"  {
			
				image image(img_binary);
		}
		
		display "Webcam image"  {
			overlay position: { 5, 5 } size: { 800 #px, 100 #px } background: # black transparency: 0.4 border: #black rounded: true
            {
            		draw "'r': run/pause the webcam " at: { 50#px,  30#px } color: # white font: font("Helvetica", 20, #bold);
            		draw "'s': save the webcam image" at: { 50#px,  60#px } color: # white font: font("Helvetica", 20, #bold);
            }
				event "s" action: save_image;
				event "r" action: activate_desactivate_webcam;
				
				image image(img_webcam);
		}
	
	display current_color_type type: 3d axes: false{
			species color_type;
			event #mouse_down action: select_color_type;
			overlay position: { 5, 5 } size: { 800 #px, 180 #px } background: # black transparency: 0.4 border: #black rounded: true
            {
            	draw "'s': save the color type" at: { 50#px,  30#px } color: # white font: font("Helvetica", 20, #bold);
            	draw "'l': load the color type" at: { 50#px,  50#px } color: # white font: font("Helvetica", 20, #bold);
            	draw "'r': reset the color type" at: { 50#px,  80#px } color: # white font: font("Helvetica", 20, #bold);
            	
            }
			event "s" action: save_types;
			event "l" action: load_color_types;
			event "r" action: reset_color_types;
		
		}		
	}
		
}