/**
* Name: DYSMA
* Based on the Imagevectorization. 
* Authors: Franck and Patrick Taillandier
* Description: Agentified sketch map - Application to Draw and Flood, Le Val case
* Tags: Sketch map, Agentification
*/

model DYSMA
global {
	string numplay<-"39";
	
	float size_max<-20000000#m2;
	float size_min<-5000#m2;
	
	string path_object <- "../generated/objects/" parameter: "Path to the object folder";
	string path_color_type <- "../generated/color_type.shp" parameter: "Path to the color type file";
	float shape_simplification <- 10.0 parameter: "Distance used for the simplification of shapes";
	float size_square <- 1.0 parameter: "Size of squares used for the vectorization";
	float min_area <- 0.0 parameter: "Mininmal area to keep an object";
	shape_file building_shapefile <- shape_file("../gis/buildings_val.shp");
	
	shape_file background_shapefile <- shape_file("../gis/monde3.shp");
	map<file,rgb> displayed_shapefiles <- [shape_file("../gis/monde3.shp")::#gray];
	shape_file water_shapefile <- shape_file("../gis/waterways_val.shp");

	float environemnt_width <- 2 #km parameter: "Width of the environment";
	float environemnt_height <- 2 #km parameter: "Height of the environment";
	pair<int,int> resolution <- 640::480 among:  [176::144,320::240,640::480, 1920::1080].pairs ;
	float max_area_envelope_coeff <- 1.0; //0.80;
	float coeff_distance_world_contour <- 0.01;
	float coeff_binary <- 1.2 parameter: "Coefficint used to build the binary image; default = 1.0, higher than 1.0 = more tolerant";
	bool load_data_at_init <- false parameter: "Load the data and vectorize the image at the initizalisation"; 
	image_file drawing_file <- image_file("../images/carte/scan/Play"+numplay+".jpg");
	
	matrix image_without_distorsion;
	point mouse_location;
	bool define_environment <- false;
	bool define_color_type <- false;
	bool define_empty_color_type <- false;
	bool delete_nat<-false;
	bool modify_nat<-false;
	bool confirm_supp_min<-false;
	bool confirm_supp_max<-false;
	
	string current_mode <- "";
	string current_mode2 <- "";
	//list<point> distorsion_points <-  [{51.06957244873047,53.33784866333008,0.0},{1401.25439453125,36.756080627441406,0.0},{1389.90625,1066.6302490234375,0.0},{57.17723846435547,1063.14111328125,0.0}];
	list<point> distorsion_points <- [{832.0654907226562,630.416015625,0.0},{2171.43896484375,634.914794921875,0.0},{2284.240478515625,1951.797119140625,0.0},{795.9772338867188,1974.3016357421875,0.0}];
	
	geometry envrionment_shape <- polygon(distorsion_points);
	string geom_polygon <- "polygon" const: true;
	string geom_line <- "line" const: true;
	string geom_raw <- "raw" const: true;
		//image to display 
	matrix img_webcam; 
	matrix img_binary;
	webcam cam <- webcam(1);  
	
	map<string, matrix<int>> mats;
	
	geometry shape <- background_shapefile = nil ? envelope(environemnt_width, environemnt_height) : envelope(background_shapefile);
	
	
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
		do save_objects ;
		create building from: building_shapefile;
		create water from: water_shapefile;
	}
	

	
	
	
	
	rgb color_image {
		matrix m <- matrix(drawing_file);
		int w <- m.columns;
		int h <- m.rows;
		point pt <- mouse_location;
		int c <- int(pt.x / world.shape.width * w) ;
		int r <- int(pt.y / world.shape.height * h) ;
		if (c >= 0) and (c < m.columns) and (r >= 0) and (r < m.rows) {
			return rgb(m[c,r]);
		}
		return #yellow;		
	}
	action info_color {
		int w <- image_without_distorsion.columns;
			int h <- image_without_distorsion.rows;
			point pt <- #user_location;
			int c <- int(pt.x / world.shape.width * w) ;
			int r <- int(pt.y /  world.shape.height * h) ;
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
			float threshold <- coeff_binary * entropy_threshold(image_without_distorsion);
			img_binary <- to_binary_image( image_without_distorsion,threshold);
			
		 	int ind_mat <- 5;
			loop i from: 0 to: img_binary.rows - 1 {
				loop j from: 0 to:ind_mat {
					img_binary[j,i] <- #black;
					img_binary[img_binary.columns -(j+1),i] <- #black;
				
				
				}
			}
			loop i from: 0 to: img_binary.columns - 1 {
				loop j from: 0 to:ind_mat {
					img_binary[i,j] <- #black;
					img_binary[i, img_binary.rows -(j+1)] <- #black;
				
				
				}
			
			}    
			
			
			
			
			int black <- int(#black);
			int white <- int(#white);
			
			int w <- image_without_distorsion.columns;
			int h <- image_without_distorsion.rows;
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
		write "Nombre d'objets : "+length(object);
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
		
		write "Saving webcam image";
		save img_webcam format: image to: "../generated/webcamImage.png";
		drawing_file <- image_file("../generated/webcamImage.png");
	
	}
	action save_objects {
		write "Saving objects";
	
	save object format: shp to: path_object + "Play"+numplay+".shp" attributes:["type_name"::type_name];
	 
	/* 	loop type over: color_type {
			list<object> objs <- object where (each.type = type);
			if not empty(objs) {
				save objs format: shp to: path_object + type.name + ".shp";
			}
		}*/
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
	}
	action load_color_types {
		do reset_color_types;
		int cpt <- 0;
		create color_type from: file(path_color_type) with: (name::get("name"), color::rgb(eval_gaml(get("col_string"))), geom_type::get("geom_type")) {
			location <- {20 #px, (1 + cpt) * 80 #px}; 
			cpt <- cpt + 1;
		}
		
	}
	
	action save_types {
		
		write "Saving color type";
		save color_type format: shp to: path_color_type attributes: ["name", "col_string", "geom_type"];
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
			int c <- int(pt.x /  world.shape.width * w) ;
			int r <- int(pt.y /  world.shape.height * h) ;
			if (c >= 0) and (c < drawing_file.contents.columns) and (r >= 0) and (r < drawing_file.contents.rows) {
				rgb col <- rgb(drawing_file.contents[c,r]);
				map  result <- user_input_dialog("Type associated to this color",[choose("Type name", string, "digue", ["digue","barrage","bassin","delocalisation"]), enter("Color", col ), choose("Geometry type", string, geom_polygon, [geom_polygon,geom_line,geom_raw]) ]);
					
				string n <- string(result["Type name"]);
				col <- rgb(result["Color"]);
				create color_type with: (color:col, col_string:("[" +col.red +"," + col.green + "," + col.blue +"]"), name:n, location : {20 #px, (1 + length(color_type)) * 80 #px}, geom_type : string(result["Geometry type"]));
				write "New " + n + " color defined";
			}
		}  else if define_empty_color_type {
			int w <- drawing_file.contents.columns;
			int h <- drawing_file.contents.rows;
			point pt <- #user_location;
			int c <- int(pt.x /  world.shape.width * w) ;
			int r <- int(pt.y /  world.shape.height * h) ;
			if (c >= 0) and (c < drawing_file.contents.columns) and (r >= 0) and (r < drawing_file.contents.rows) {
				rgb col <- rgb(drawing_file.contents[c,r]);
				create color_type with:(	color: col,col_string:("[" +col.red +"," + col.green + "," + col.blue +"]"),	name:"Empty", location : {20 #px, (1 + length(color_type)) * 50 #px}); 
				write "New Empty color defined";
			}
		}
	}
	
		action mouse_click2 {
			
		if delete_nat {
			point pt <- #user_location;
			ask nature overlapping pt {
				do die;
			}
			}
			if modify_nat {
			point pt <- #user_location;
			ask nature overlapping pt {
				write "mod";
					map  result <- user_input_dialog("Type associated to this color",[choose("Type name", string, "digue", ["digue","barrage","bassin","delocalisation"]), enter("Color", col ), choose("Geometry type", string, geom_polygon, [geom_polygon,geom_line,geom_raw]) ]);
					string n <- string(result["Type"]);
			

			}
			}	
			
			
	}
	
}

species nature {

		
		int type; //0 : Nature technisiste ; 1: Allée d'arbres ; 2 : Gestion traditionnelle ; 3 : Berge aménagée
				// 4 : Agriculture urbaine ; 5 : Forêt urbaine, 6:Gestion différenciée
				// 7 : Ripisylve sauvage , 8 : Friche renaturée


	rgb color<-#green;
	rgb color_bord<-#green;
	list<int> col<-[0,255,0];
	bool light<-false;
	bool to_die<-false;
	

	
			aspect map_base
	{
		draw shape color:color;
		
		//draw shape color:color border:color_bord width:10#m;
			//	draw ""+state color:#black  font:font("Helvetica", 20, #plain) depth:5;
		
	}

}

species test_form {
	aspect default
	{
		draw shape  border:#red wireframe:true;
	}
	
}



species building
{

	aspect default
	{
		draw shape color: #orange;
	}

}


species water
{
	string type;
	aspect default
	{
		draw shape color: #blue;
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
	string col_string;
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
	
	parameter "max nature size" var:size_max<- 100000.0 min: 10000.0 max: 10000000.0 category: "max size";	  
	parameter "min nature size" var:size_min<- 1000.0 min: 100.0 max: 10000.0 category: "max size";
	
	
	parameter "Path to the object folder" var:path_object  ;
	parameter "Path to the color type file" var:path_color_type  ;
	parameter "Distance used for the simplification of shapes" var:shape_simplification  ;
	parameter "Size of squares used for the vectorization" var:size_square  ;
	parameter "Mininmal area to keep an object" var:min_area  ;

	
	parameter "Width of the environment" var:environemnt_width  ;
	parameter "Height of the environment" var:environemnt_height  ;
	
	
	output {
		 layout horizontal([0::6000,vertical([1::5000,2::5000])::5000]) tabs:true editors: false;
		
		display image type: 3d  axes: false {
			
			overlay position: { 5, 5 } size: { 800 #px, 180 #px } background: # black transparency: 0.4 border: #black rounded: true
            {
            	draw "current action: " + current_mode at: { 50#px,  30#px } color: # white font: font("Helvetica", 30, #bold);
    	
            	draw "'b': define the environment points" at: { 50#px,  80#px } color: # white font: font("Helvetica", 20, #bold);
            	draw "'c': define a new color type" at: { 50#px,  100#px } color: # white font: font("Helvetica", 20, #bold);
            	draw "'e': define the empty color type" at: { 50#px,  120#px } color: # white font: font("Helvetica", 20, #bold);
            	draw "'v': vectorizing image" at: { 50#px,  60#px } color: # white font: font("Helvetica", 20, #bold);
            	draw "'s': save the created objects" at: { 50#px,  140#px } color: # white font: font("Helvetica", 20, #bold);
            }
			image drawing_file refresh: true ;
			graphics "displayed shapefile" transparency: 0.5{
				if not empty(displayed_shapefiles) {
					loop data_shape over: displayed_shapefiles.keys {
						draw shape_file(data_shape) color: displayed_shapefiles[data_shape] ;
					}
					
				}
			}
			event "v" action: vectorizing_image;
			event "b" action: define_environment_points;
			event "c" action: define_color_type;
			event "e" action: define_empty_color_type;
			event "s" action: save_objects;
			
			event #mouse_move action: define_mouse_loc;
			event #mouse_down action: mouse_click;
			graphics "mouse_loc" {
				draw circle(5) at: mouse_location border: #black color: world.color_image();
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
	

	
	display "Image without distorsion"  {
   
    image image(image_without_distorsion);
  }
  

  
  display "Binary image"  {
   
    image image(img_binary);
  }
  
 /*  
	display "Techno" {
   image mats["0 : Nature technisiste"];
  }
 	display "Arbre" {
   image mats["1 : Allee arbres"];
  }
  	display "Tradi" {
   image mats["2 : Gestion traditionnelle"];
  }
  	display "Berge" {
   image mats["3 : Berge amenagee"];
  }
  	display "Agri" {
   image mats["4 : Agriculture urbaine"];
  }
    display "Foret" {
   image mats["5 : Foret urbaine"];
  }
  	display "Diff" {
   image mats["6 : Gestion différenciee"];
  }
  	display "Ripi" {
   image mats["7 : Ripisylve sauvage"];
  }
  	display "Friche" {
   image mats["8 : Friche renaturee"];
  }
  */
  		display "Image without distorsion"  {
			
				image image(image_without_distorsion) ;
				graphics "background" transparency: 0.5{
				if background_shapefile != nil {
						draw background_shapefile color: #gray ;
					}
				}
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
	display current_color_type type: 3d axes: false background: rgb(230,230,230){
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
