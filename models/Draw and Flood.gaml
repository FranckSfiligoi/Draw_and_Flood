/**
* Name: Draw and Flood
* Author:  Franck Taillandier
* Description: Model which simulates flood from agentified sketch map, Application to Le Val
* Tags:  flood simulation, game, sketch map
*/
model Draw_and_Flood


global
{
	int nb_pl<-12;
	float cell_size<-1.0;
	string numplay<-string(nb_pl);
	bool mode_no_protec<-false;
	bool mode_all_test<-false;
	shape_file building_shapefile <- shape_file("../gis/buildings_val.shp");
	shape_file monde_shapefile <- shape_file("../gis/monde3.shp");
	shape_file road_shapefile <- shape_file("../gis/roads_val.shp");
	shape_file water_shapefile <- shape_file("../gis/waterways_val.shp");
	shape_file barrage_shp <-shape_file("../generated/objects/barrage.shp");
	shape_file bassin_shp <-shape_file("../generated/objects/bassin.shp");
	shape_file digue_shp <-shape_file("../generated/objects/digue.shp");
	shape_file delocalisation_shp <-shape_file("../generated/objects/delocalisation.shp");
	shape_file flood_shp;
	
	
	
	
	
	bool barrage<-false;
	bool deloc<-true;
	bool digue<-false;
	bool bassin<-true;
	
	
	file grid_val<-csv_file( "../gis/grid_val.csv",true);
	matrix data_alti <- matrix(grid_val);
	
	cell input_water_cell;
	
	
	geometry shape <- envelope(monde_shapefile);
	
	bool mode_fond_carte<-false;
	
	//compute the size of the environment from the envelope of the OSM file
	//geometry shape <- envelope(osmfile);
	//geometry shape <- envelope(nature_shp);
	float max_value;
	float min_value;
	
	string descrip_flood;
	float time_simulation <- 2 #h;
	//float water_input_average <- 10 * 10 ^ 6 #m3 / #h;
	float water_input_average <- 20 * 10 ^ 5 #m3 / #h;
	float time_start_water_input <- 0 #h;
	float time_last_water_input <- 2 #h;
	int water_intensity_intensity_type <- 0; //0 :const ; 1: croissant ; 2 : decroissant ; 3 : aleatoire
	float rain_intensity_average <- 5 #cm;
	float time_start_rain <- 0 #h;
	float time_last_rain <- 2 #h;
	int rain_intensity_type <- 0; //0 :const ; 1: croissant ; 2 : decroissant ; 3 : aleatoire
	float initial_soil_water<-0.0;
	int leaving_people <- 0;
	list<cell> flooded_cell;
	int nb_flooded_cell;
	list<cell> escape_cells;
	list<cell> river_cells;
	list<road> safe_roads;
	float cumul_water_enter;
	string nb_blesse;
	string nb_mort;
	list<float> rain_intensity;
	list<float> water_input_intensity;
	int flooded_building <- 0;
	float average_building_state;
	float max_water_he <- 0.0;
 
	bool first_flood_turn <- true;
		float time_start;
	string date_in;
	bool end_simu<-false;
	
	init {
	 step <- 1 #mn;
	
	
	if nb_pl>0 {
			flood_shp <-shape_file("../generated/objects/Play"+numplay+".shp");
	}

	int i<-0;
		ask cell {
		//_alti {
		
		altitude<-float(data_alti[12,i]);
		i<-i+1;
	}
	
	/*ask cell {
		list<cell_alti> ca<-cell_alti overlapping self;
		altitude<-ca mean_of (each.altitude);
	}
	write one_of(cell_alti).shape.height;
	write one_of(cell_alti).shape.width;
	//13.764412960875916
	//18.368413632713327
	*/
	min_value<- cell min_of(each.altitude);
	max_value<- cell max_of(each.altitude);

		ask cell {
	int val <- int(255 * ( 1  - ((altitude - min_value) /(max_value - min_value))));
			color <- rgb(val,val,val);
			//plus c'ets noir, plus c'est haut
		}
	create building from: building_shapefile {
	if not (self overlaps world) {
				do die;
			}
			my_cells<-cell overlapping self;
			}
	
	ask building {
		ask building overlapping self {do die;}
	}
	create road from: road_shapefile {
if not (self overlaps world) {
				do die;
			}
			
			}
			
			ask road {
			do 	breakdown_segment;
	do breakdown_distance;
			
			}
			
			
			
	create water from: water_shapefile {
	if not (self overlaps world) {
				do die;
			}
		if  !mode_fond_carte {ask cell overlapping self {is_river<-true;
		//	color <- #aqua;
		}	
		}
			}
	
	ask water {		do 	breakdown_segment;
	do breakdown_distance;}


	if !mode_no_protec {
		
			if nb_pl>0 {
			create object from:flood_shp;
	}
	
		
	ask object {
		if type_name="digue" {
				create obstacle {
				shape<-myself.shape;
				location<-myself.location;
				height <- 1.5 #m;
				my_cells <- cell overlapping self;
			altitude <- my_cells min_of (each.altitude);
			ask my_cells {
				is_dyke <- true;
				dyke_height <- myself.height;
			}
			}
		}
		if type_name="barrage"{
					create obstacle {
				shape<-myself.shape;
				location<-myself.location;
				height <- 10 #m;
				my_cells <- cell overlapping self;
			altitude <- my_cells min_of (each.altitude);
			ask my_cells {
				is_dam <- true;
				dyke_height <- myself.height;
			}
			}
		}
		if type_name="bassin" {
			create pool {
				shape<-myself.shape;
				location<-myself.location;
				volume<-shape.area*depth;
				//my_neigh_cells<- cell at_distance(distance_application);
				my_neigh_cells<- cell overlapping self;
						ask building overlapping self {
		do die;
	}	
			}
		}
		if type_name="delocalisation" {
				ask building overlapping self {
		do die;
	}	
		create delocalisation_area  {
				shape<-myself.shape;
				location<-myself.location;
			}
		}
		
		
	}
	
ask obstacle {do define_color;}
			}	

list<cell> riv<-cell where(each.is_river);
riv<-riv sort_by(each.location.x);
float prev_alt<-riv max_of(each.altitude);
ask riv {
	altitude<-min(altitude,prev_alt-0.6#m);
	prev_alt<-altitude;
}


float max_alt<-cell where (each.is_river) max_of(each.altitude);
float max_x<-cell where (each.is_river) min_of(each.location.x);
input_water_cell<-one_of(cell where (each.is_river and each.altitude=max_alt));
//input_water_cell<-one_of(cell where (each.is_river and each.location.x=max_x));



//write world.shape.perimeter;
//write world.shape.area;
	}
//fin init


	reflex go_water {
			float time_flood<-time-time_start;
			if first_flood_turn = true {
			ask cell{water_height_max<-0.0;}
			ask river_cells {
					water_volume<-initial_soil_water*100;
					do compute_water_altitude;
				}
				rain_intensity<-nil;
				water_input_intensity<-nil;
				
				loop i from: 0 to: int(time_last_rain / step) {
					add rain_intensity_average to: rain_intensity;
				}
				
				loop i from: 0 to: int(time_last_water_input / step) {
					add water_input_average to: water_input_intensity;
					
				}
				time_start<-time;
				
				first_flood_turn <- false;
			}
			
		 	if (time mod 20 #mn) = 0 and !mode_all_test{
				write "avancée de l'inondation : "+round(time_flood/time_simulation*100)+" %";
			} 
			
			do flower;


			max_water_he <- max([max_water_he, cell max_of (each.water_height)]);
			

			if (time = time_start + time_simulation) {
				if mode_all_test {
					write length(building where(each.serious_flood));
					end_simu<-true;
				}
				else {
					write "***************************";
					write "Bilan de l'inondation :";
					write "Player : "+numplay;
					write "Nombre de bâtiments inondés :"+length(building where(each.serious_flood));
					write "hauteur d'eau max : "+max_water_he; 
					ask cell {do update_water_color_final ;}
					ask building {do update_water_color_final ;}
					do pause;
			
			
			}
			}

	}


	action flower {
		float t <- machine_time;
		
		int incre <- 0;
		ask cell {
			if time >= time_start + time_start_rain and time - time_start - time_start_rain < time_last_rain {
				water_volume <- water_volume + rain_intensity[incre] * cell_area * step / 1 #h;
			}
		}

		if time >= time_start + time_start_water_input and time - time_start - time_start_water_input < time_last_water_input {	
				ask input_water_cell  {
					cumul_water_enter <- cumul_water_enter + water_input_intensity[incre];
					water_volume <- water_volume + water_input_intensity[incre];
					do compute_water_altitude;
				}
			
			

		}

		if (time mod 15 #mn) = 0 {
			incre <- incre + 1;
		}

		

		ask building {
			neighbour_water <- false;
			water_cell <- false;
		}

		ask pool {do collect_water;}
		ask cell {
			if (water_volume > 1 #m3 ) {
			do absorb_water;
			if is_pluvial_network {water_volume <- max([0, water_volume - water_evacuation_pl_net * step]);			}
			}
			
			if (water_volume <= 1 #m3 or is_sea) {already <- true;} 
			else {already <- false;}

		}

		list<cell> flowing_cell <- cell where (each.already=false);
		list<cell> cells_ordered <- flowing_cell sort_by (each.water_altitude);	
		ask cells_ordered {
			do flow;
		}

	
		

		 
		ask (cell where (each.water_height >= 0.5 #m)) {
			add self to: flooded_cell;
		}
		flooded_cell <- remove_duplicates(flooded_cell);
		
		ask building {
			do update_water;
		//	do update_water_color;
			
		}
		ask cell{do update_color;}
		
	}

}



species object {
	string type_name;
}


species osm_agent
{
	string highway_str;
	string building_str;
	string water_str;
}

species road
{
	rgb color <-#black;
	string type;
	list<cell> my_cells;
	float long;

	action breakdown_segment {
			list<geometry> plr<- to_segments(shape);
			 	loop g over: plr {
				create road {
					shape<-g;
					long<-shape.perimeter/2;
					location<-g.location;
					if not (self overlaps world) {do die;}
					my_cells <- cell overlapping self;
					}
				}
		do die;
		}
		
		
		
	action breakdown_distance {		
			list pr <-points_on(shape,100.0#m);
			loop pi over:pr {
			loop g over: split_at(shape,pi) {
				create road {
					shape<-g;
					long<-shape.perimeter/2;
					location<-g.location;
					if not (self overlaps world) {do die;}
					my_cells <- cell overlapping self;
					}
				}
				do die;
			}
		
	}
	
	
	aspect default
	{
		draw shape color: color width:3;
	}

}

species water
{
	string type;
	list<cell> my_cells;
	float long;	
	rgb color <- #blue;
	cell cell_origin;
	cell cell_destination;
	float river_height <- 0 #m;
	float altitude;
	point my_location;
	float river_length;
	float state <- 1.0;
	float river_broad;
	float river_depth;
	
	
	action breakdown_segment {
			list<geometry> plr<- to_segments(shape);
			 	loop g over: plr {
				create water{
					shape<-g;
					long<-shape.perimeter/2;
					location<-g.location;
					if not (self overlaps world) {do die;}
					my_cells <- cell overlapping self;
					}
				}
		do die;
		}
		
		action breakdown_distance {		
			list pr <-points_on(shape,10.0#m);
			loop pi over:pr {
			loop g over: split_at(shape,pi) {
				create water {
					shape<-g;
					long<-shape.perimeter/2;
					location<-g.location;
					if not (self overlaps world) {do die;}
					my_cells <- cell overlapping self;
					}
				}
				do die;
			}
		
	}
	
	aspect default
	{
		draw shape color: #blue width:6;
	}

}

/*species node_agent
{
	string type;
	aspect default
	{
		draw square(3) color: # grey;
	}

}*/

species building
{
	string type;
	int my_number;
	int category; //0: residentiel, 1: commerce, 2:erp
	int importance<-1;
	list<cell> my_cells;
	list<cell> my_neighbour_cells;
	float altitude;
	float impermeability <- 0.7;
	float water_height <- 0.0;
	float history_water_heigth;
	float water_evacuation <- 0.5 #m3 / #mn;
	point my_location;
	float bd_height;
	float state <- 1.0; //entre 0 et 1
	float damage<-0.0;
	float vulnerability <- 0.7;
	float value<-0.5; //0: vide aucune valeur -> 1. valeur très très forte
	bool is_water;
	rgb my_color <- #white;
	rgb my_border_color<-#black;
	bool nrj_on <- true;
	bool vegetalise <- false;
	int nb_stairs <- -1;
	bool serious_flood <- false;
	float water_level_flooded <- 15 #cm;
	bool neighbour_water <- false;
	bool water_cell <- false;
	bool new_building<-false;
	bool implemented<-true;
	int Niveau_act;
	float veg_state<-1.0;
	int nb_pot_pp;

	action update_water {
		float cell_water_max;
		cell_water_max <- max(my_cells collect each.water_height);
		if water_height < cell_water_max {
			water_height <- water_height + (cell_water_max - water_height) * (1 - impermeability);
		} 

	if water_height > water_level_flooded {
			serious_flood <- true;
			//my_color <- #red;
			do update_water_color;
		}

		/*if not water_cell {
			water_cell <- cell_water_max > 10 #cm;
		}

		if not neighbour_water {
			neighbour_water <- (my_neighbour_cells first_with (each.water_height > 10 #cm)) != nil;
		}*/

	}


		action update_water_color_final {

			if serious_flood  {
				my_color <- #yellow;
				my_border_color<-#red;
			}
	}

	action update_water_color {
			int val_water <- 0;
			val_water <- max([0, min([255, int(255 * (1 - (water_height / 1.0 #m)))])]);
			if water_height > 5 #cm {
			my_color <- rgb([255, val_water, val_water]);
			}
				if serious_flood  {
				my_color <- #yellow;
				my_border_color<-#red;
			}
			
	}

	aspect default
	{
		draw shape color: my_color border:my_border_color width:2;
	}

}



//***********************************************************************************************************
//*************************** CELL **********************************************************************
//***********************************************************************************************************

grid cell_alti neighbors:8 {
		
	float altitude;



}


//grid cell neighbors:8 cell_height:13.764412960875916*cell_size cell_width:18.368413632713327*cell_size{
	grid cell neighbors:8 {
	bool is_active <- false;
	float coef_color<-10.0;
	float water_height;
	float water_height_max;
	float water_river_height;
	float water_volume;
	float altitude <- grid_value;
	bool is_river <- false;
	bool is_river_full <- false;
	bool is_sea <- false;
	bool is_dyke <- false;
	bool is_dam <- false;
	bool is_natura <- false;
	bool is_pluvial_network <- false;
	bool is_parking <- false;
	bool permeabilise <- false;
	bool jardin_pluie <- false;
	bool puits_infiltration <- false;
	float water_evacuation_pl_net <- 0.0;
	float permeability <- 0.0;
	bool already;
	float water_cell_altitude;
	float river_altitude;
	float water_altitude;
	float remaining_time;
	list<building> my_buildings;
	list<water> my_rivers; 
	float cell_area <- shape.area; 
	list<nature> my_green_areas;
	float river_broad <- 1.0; 
	float river_depth <- 1.0;
	bool escape_cell;
	rgb color_plu;
	rgb histo_color;
	rgb topo_color;
	int plu_typ <- 0; // 0: urbain, 1: a urbaniser, 2:agricole, 3:nat, 4:mer 
	float distance_to_river;
	list<cell> close_cells;

	
	//dyke
	float dyke_height <- 0.0;
	float water_pressure; //from 0 (no pressure) to 1 (max pressure)
	float breaking_probability <- 0.01; //we assume that this is the probability of breaking with max pressure for each min
	float dyke_state;
	bool let_river;
	bool is_critical <- false;
	float level_crit<-0.1 #m;

	float water_abs <- 0.0;
	float water_abs_alr <- 0.0;
	float water_abs_max <- 0.01;
	map<cell, float> delta_alt_neigh;
	map<cell, float> slope_neigh;
	list<cell> flow_cells;
	float volume_max;
	float volume_distrib;
	float volume_distrib_cell;
	bool is_flowed <- false;
	bool may_flow_cell;
	float prop_flow;
	float prop<-1.0;
	
		//Update the color of the cell
	action update_color {
		if (!is_sea) {
	//		color <- rgb(int(min([255, max([245 - 0.8 * altitude, 0])])), int(min([255, max([245 - 1.2 * altitude, 0])])), int(min([255, max([0, 220 - 2 * altitude])])));
		}

		int val_water <- 0;

		if (is_river) {	
		//		color <- #aqua;
		}

		if (water_height > 5 #cm) {
			val_water <- max([0, min([200, int(200 * (1 - (water_height*coef_color)))])]);
		//	color <- rgb([val_water, val_water, 255]);
		}

		if is_critical {
			color <- #darkblue;
		}

	}
	
	
	action update_water_color_final {

			if is_critical {
				color <- #darkblue;
			}
	}
	
	
	
	action compute_permeability {
		if plu_typ = 0 {
			permeability <- 0.01;
			water_abs_max <- shape.area * 0.1 #cm;
			if permeabilise {
				permeability <- 0.1;
				water_abs_max <- shape.area * 10 #cm;
			}

			if jardin_pluie {
				permeability <- permeability + 0.6;
				water_abs_max <- water_abs_max + shape.area * 100 #cm;
			}

			if puits_infiltration {
				permeability <- permeability + 0.5;
				water_abs_max <- water_abs_max + 40 #m3;
			}
			
			}


		if plu_typ = 1 {
			permeability <- 0.15;
			water_abs_max <- shape.area * 30 #cm;
		}

		if plu_typ = 2 {
			permeability <- 0.25;
			water_abs_max <- shape.area * 50 #cm;
		}

		if plu_typ = 3 {
			permeability <- 1;
			water_abs_max <- shape.area * 100 #cm;
		}
		
		
		if my_green_areas!=nil {
			permeability<-max([permeability,my_green_areas max_of(each.state*0.7)]);
			water_abs_max <-max([water_abs_max ,my_green_areas max_of(each.state*150 #cm *shape.area)]);
		}


	}
	
	
	action absorb_water {
		water_abs<-max([0,min([water_abs_max-water_abs_alr,water_volume*permeability])]);
		water_abs_alr <- water_abs_alr+water_abs;
		water_volume <- water_volume  - water_abs;
	}

	action compute_water_altitude {
		is_river_full <- true;
		float water_volume_no_river <- water_volume;
		water_river_height <- 0.0;
		if is_river {
			float vol_river <- max([river_broad * sqrt(cell_area) * river_depth]);
			float prop_river <- water_volume / vol_river;
			water_river_height <- river_depth;
			if prop_river < 1 {
				is_river_full <- false;
				vol_river <- water_volume;
				water_river_height <- river_depth * prop_river;
			}
			water_volume_no_river <- water_volume - vol_river;
		}

		water_height <- max([0, water_volume_no_river / cell_area]);
		water_altitude <- altitude - river_depth + water_river_height + water_height;
		if water_height_max<water_altitude {water_height_max<-water_altitude;}
		if water_height > level_crit {
			is_critical <- true;
		}
		

	}
		//Action to flow the water 
	action flow {
		is_flowed <- false;
		
		float w_a <- water_altitude;
		
		bool from_river<-is_river;
		bool from_dyke<-is_dyke;
		bool from_dam<-is_dam;
		float from_dh<-dyke_height;
		
		ask neighbors  where (each.already) {
			prop_flow <-0.0;
			bool let_pass<-(from_river and is_river);
			let_pass<-false;
			bool obst_to<-(is_dyke and !let_pass) or is_dam;
			bool obst_from<-(from_dyke and !let_pass) or from_dam;
			if !obst_to and !obst_from and w_a > water_altitude {prop_flow <-w_a - water_altitude;}
			if obst_to and !obst_from and w_a > water_altitude and w_a >(altitude+dyke_height) {prop_flow <-min([w_a-(altitude+dyke_height),w_a - water_altitude]);}
			if !obst_to and obst_from and w_a > water_altitude and w_a >(altitude+from_dh) {prop_flow <-min([w_a-(altitude+from_dh),w_a - water_altitude]);}
			
			if obst_to and obst_from and w_a > water_altitude and w_a >(altitude+max(from_dh,dyke_height)) {prop_flow <-min([w_a-(altitude+max(from_dh,dyke_height)),w_a - water_altitude]);}
	
		}
		volume_distrib <- water_volume*prop;
		list<cell> ntf<-neighbors  where (each.already and each.prop_flow>0);
		float tot_den <-ntf sum_of(each.prop_flow);
		ask ntf {
				volume_distrib_cell <- myself.volume_distrib * prop_flow/tot_den;
				water_volume <- water_volume + volume_distrib_cell;
				do compute_water_altitude;
		}
		water_volume<-water_volume-volume_distrib;
		do compute_water_altitude;
		already <- true;
		

	}
	
	
	aspect map {
	
			draw shape color: color;
		}
		
	

	aspect map3D {
		draw square(sqrt(cell_area)) color: color depth: altitude;
	}
	
	
	
}

//***********************************************************************************************************
//*************************** OBSTACLE **********************************************************************
//***********************************************************************************************************
species obstacle {
	float height <- 2 #m;
	float altitude;
	int resistance <- 2;
	rgb color <- #violet;
	bool is_destroyed <- false;
	list<cell> my_cells;
	bool let_river<-true;

	action define_color {
		if height<2#m {color<-#black;}
		else {color<-#darkcyan;}
	}

	aspect default {
		draw shape + (0.5, 10, #flat) depth: height color: color at: location + {0, 0, height};
	}

}

//***********************************************************************************************************
//*************************** DELOCALISATION **********************************************************************
//***********************************************************************************************************
species delocalisation_area {
	
		aspect default {
			draw shape  border: #red;
		}
}
//***********************************************************************************************************
//***************************  BASSIN    **********************************************************************
//***********************************************************************************************************
species pool {
	list<cell> my_cells;
	list<cell> my_neigh_cells;
	float volume;
	float depth<-2#m;
	float water_into <- 0.0;
	float distance_application <- 10 #m;
	float state<-1.0;

	
	action collect_water {
		if (water_into < volume*state) {
			ask my_neigh_cells {
				if (myself.water_into + water_volume < myself.volume*myself.state) {
					myself.water_into <- myself.water_into + water_volume;
					water_volume <- 0.0;
					do compute_water_altitude;
				}

			}

		}

	}


	aspect default {
			draw shape color:#green border: #black;
		}

}


species nature {
	float state<-0.5+rnd(5)/10;
	rgb color<-#green;
	
	reflex updat_state {
		state<-state-0.1*rnd(10)/100;
		
		
		color<-rgb(int(255 * (1 - state)), 255, int(255 * (1 - state)));
		
		
	}
	
	
		aspect default
	{
		draw shape color:color border:#black;
	}
}


experiment 'all_test' type: batch repeat: 1 keep_seed: true until:end_simu {
	parameter 'solution' var:nb_pl min:1 max:38 step:1;

}

experiment "Let's go" type: gui
{
	//parameter "File:" var: osmfile <- file<geometry> (osm_file("../includes/map.osm", filtering));
	output
	{
		display map type: 3d
		{
			//grid cell;
			//species cell  aspect: map3D;
			species cell  aspect: map;
			species building;
			species road;
			species water;
			species obstacle;
			species pool;
			species delocalisation_area;
			//species node_agent refresh: false;
			species nature;

			
		}

	}

}

