/**
* Name: OSM file to Agents
* Author:  Patrick Taillandier
* Description: Model which shows how to import a OSM File in GAMA and use it to create Agents. In this model, a filter is done to take only into account the roads 
* and the buildings contained in the file. 
* Tags:  load_file, osm, gis
*/
model FloodNV2


global
{
	int numplaymax<-38;
	bool mode_no_protec<-false;
	shape_file building_shapefile <- shape_file("../gis/buildings_val.shp");
	shape_file monde_shapefile <- shape_file("../gis/monde3.shp");
	shape_file road_shapefile <- shape_file("../gis/roads_val.shp");
	shape_file water_shapefile <- shape_file("../gis/waterways_val.shp");
	shape_file barrage_shp <-shape_file("../generated/objects/barrage.shp");
	shape_file bassin_shp <-shape_file("../generated/objects/bassin.shp");
	shape_file digue_shp <-shape_file("../generated/objects/digue.shp");
	shape_file delocalisation_shp <-shape_file("../generated/objects/delocalisation.shp");
	
	int nb_el;
	float nb_el_avr;
	float nb_dam;
	float nb_dyke;
	float nb_deloc;
	float nb_pool;
	int coef<-5;
	float cell_size<-5#m;
	int nb_play_dam<-0;
	int nb_play_dyke<-0;
	int nb_play_deloc<-0;
	int nb_play_pool<-0;
	int cost_action<-0;
	
	
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
 
	list<int> seuil_color<-[0,0,1,1,2,2,3,4,5];
	
	init {
	 step <- 1 #mn;
	int i<-0;

	
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
	
	loop it from:41 to:41 {
	//loop it from:1 to:numplaymax {
	shape_file flood_shp <-shape_file("../generated/objects/Play"+it+".shp");
		bool di<-false;
		bool da<-false;
		bool de<-false;
		bool ba<-false;
	create object from:flood_shp {

		
		if type_name="digue" {
				di<-true;
				create obstacle {
				shape<-myself.shape;
				location<-myself.location;
				height <- 1.5 #m;
				my_cells <- cell overlapping self;
				cost_action<-cost_action+1;
				
			ask my_cells {
				is_dyke <- true;
				dyke_height <- myself.height;
			}
			}
		}
		if type_name="barrage"{
				da<-true;
				create obstacle {
				shape<-myself.shape;
				location<-myself.location;
				height <- 10 #m;
				my_cells <- cell overlapping self;
				cost_action<-cost_action+6;
				
			ask my_cells {
				is_dyke <- true;
				dyke_height <- myself.height;
			}
			}
		}
		if type_name="bassin" {
			ba<-true;
			create pool {
				shape<-myself.shape;
				location<-myself.location;
				volume<-shape.area*depth;
				my_neigh_cells<- cell at_distance(20#m);
				cost_action<-cost_action+2;
					ask building overlapping self {
					cost_action<-cost_action+3;
				do die;
	}	
			
				
			}
		}
		if type_name="delocalisation" {
				de<-true;
				ask building overlapping self {
					cost_action<-cost_action+3;
		do die;
	}	
		create delocalisation_area  {
				shape<-myself.shape;
				location<-myself.location;
			}
		}
		
		
		}
		
		if da {nb_play_dam<-nb_play_dam+1;}
		if di {nb_play_dyke<-nb_play_dyke+1;}
		if de {nb_play_deloc<-nb_play_deloc+1;}
		if ba {nb_play_pool<-nb_play_pool+1;}

write cost_action;
cost_action<-0;
	}
	
			}	

list<cell> riv<-cell where(each.is_river);



//write world.shape.perimeter;
//write world.shape.area;
	
	do give_stat;
	ask cell {do compute_color; }
	
	
	
	
	}
//fin init


action give_stat {
	nb_el<-length(object);
	nb_el_avr<-(with_precision((nb_el/numplaymax) ,2));
	nb_dam<-( with_precision(length(obstacle where(each.height>2#m))/nb_el*100,2));
	nb_dyke<-( with_precision(length(obstacle where(each.height<2#m))/nb_el*100,2));
	nb_deloc<-(with_precision(length(delocalisation_area)/nb_el*100 ,2));
	nb_pool<-( with_precision(length(pool)/nb_el*100,2));
	
	write "nb elements : "+nb_el;
	write "Nb moyen d'élements : "+nb_el_avr;
	write "% de barrage : "+nb_dam;
	write "% de digue : "+nb_dyke;
	write "% de delocalisation : "+nb_deloc;
	write "% de bassin : "+nb_pool;
	
	write "% participants ayant utilisé un bassin : "+ nb_play_pool/numplaymax*100;
	write "% participants ayant utilisé un barage : "+ nb_play_dam/numplaymax*100;
	write "% participants ayant utilisé une dique : "+ nb_play_dyke/numplaymax*100;
	write "% participants ayant utilisé la délocalisation : "+ nb_play_deloc/numplaymax*100;
	
	
	
	
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

	
	aspect default
	{
		draw shape color: my_color border:my_border_color width:2;
	}

}



//***********************************************************************************************************
//*************************** CELL **********************************************************************
//***********************************************************************************************************

grid cell neighbors:8 cell_height:cell_size cell_width:cell_size{
		
	
	bool is_river <- false;
	bool is_sea <- false;
	bool is_dyke <- false;
	
	list<building> my_buildings;
	list<water> my_rivers; 
	float cell_area <- shape.area; 
	list<nature> my_green_areas;
	float river_broad <- 1.0; 
	float river_depth <- 1.0;
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
	
	rgb dyke_col;
	rgb dam_col;
	rgb pool_col;
	rgb deloc_col;
	
	action compute_color {
		int nb_dyke_cell<-length((obstacle overlapping self where(each.height<2#m)));
		int nb_dam_cell<-length((obstacle overlapping self where(each.height>2#m)));
		int nb_pool_cell<-length((pool overlapping self ));
		int nb_deloc_cell<-length((delocalisation_area overlapping self ));
	
	//write nb_pool_cell/nb_pool*255*5;
	
//	pool_col<-rgb(int(255*(1-(coef*nb_pool_cell/nb_pool))),int(255),int(255*(1-(coef*nb_pool_cell/nb_pool))));
//	dyke_col<-rgb(int(255*(1-coef*nb_dyke_cell/nb_dyke)),int(255*(1-coef*nb_dyke_cell/nb_dyke)),255*(1-coef*nb_dyke_cell/nb_dyke));
//	dam_col<-rgb(int(255*(1-coef*nb_dam_cell/nb_dam)),int(255*(1-coef*nb_dam_cell/nb_dam)),255);
//	deloc_col<-rgb(255,int(255*(1-coef*nb_deloc_cell/nb_deloc)),255*(1-coef*nb_deloc_cell/nb_deloc));
	
	pool_col<-#white;
	dyke_col<-#white;
	dam_col<-#white;	
	deloc_col<-#white;
	
	
	if nb_dyke_cell>seuil_color[0] {dyke_col<-rgb(210,210,210);}
	if nb_dyke_cell>seuil_color[1] {dyke_col<-rgb(180,180,180);}
	if nb_dyke_cell>seuil_color[2] {dyke_col<-rgb(150,150,150);}
	if nb_dyke_cell>seuil_color[3] {dyke_col<-rgb(120,120,120);}
	if nb_dyke_cell>seuil_color[4] {dyke_col<-rgb(90,90,90);}
	if nb_dyke_cell>seuil_color[5] {dyke_col<-rgb(60,60,60);}
	if nb_dyke_cell>seuil_color[6] {dyke_col<-rgb(30,30,30);}
	if nb_dyke_cell>seuil_color[7] {dyke_col<-rgb(0,0,0);}
	
	
	
	if nb_dam_cell>seuil_color[0] {dam_col<-rgb(210,210,210);}
	if nb_dam_cell>seuil_color[1] {dam_col<-rgb(180,180,180);}
	if nb_dam_cell>seuil_color[2] {dam_col<-rgb(150,150,150);}
	if nb_dam_cell>seuil_color[3] {dam_col<-rgb(120,120,120);}
	if nb_dam_cell>seuil_color[4] {dam_col<-rgb(90,90,90);}
	if nb_dam_cell>seuil_color[5] {dam_col<-rgb(60,60,60);}
	if nb_dam_cell>seuil_color[6] {dam_col<-rgb(30,30,30);}
	if nb_dam_cell>seuil_color[7] {dam_col<-rgb(0,0,0);}
	
	
	if nb_pool_cell>seuil_color[0] {pool_col<-rgb(210,210,210);}
	if nb_pool_cell>seuil_color[1] {pool_col<-rgb(180,180,180);}
	if nb_pool_cell>seuil_color[2] {pool_col<-rgb(150,150,150);}
	if nb_pool_cell>seuil_color[3] {pool_col<-rgb(120,120,120);}
	if nb_pool_cell>seuil_color[4] {pool_col<-rgb(90,90,90);}
	if nb_pool_cell>seuil_color[5] {pool_col<-rgb(60,60,60);}
	if nb_pool_cell>seuil_color[6] {pool_col<-rgb(30,30,30);}
	if nb_pool_cell>seuil_color[7] {pool_col<-rgb(0,0,0);}
	
	if nb_deloc_cell>seuil_color[0] {deloc_col<-rgb(210,210,210);}
	if nb_deloc_cell>seuil_color[1] {deloc_col<-rgb(180,180,180);}
	if nb_deloc_cell>seuil_color[2] {deloc_col<-rgb(150,150,150);}
	if nb_deloc_cell>seuil_color[3] {deloc_col<-rgb(120,120,120);}
	if nb_deloc_cell>seuil_color[4] {deloc_col<-rgb(90,90,90);}
	if nb_deloc_cell>seuil_color[5] {deloc_col<-rgb(60,60,60);}
	if nb_deloc_cell>seuil_color[6] {deloc_col<-rgb(30,30,30);}
	if nb_deloc_cell>seuil_color[7] {deloc_col<-rgb(0,0,0);}
	
	}
	
	
	aspect map_pool {
		draw shape color:pool_col;
		}
		
		aspect map_dyke {
		draw shape color:dyke_col;
		}
		
		aspect map_dam {
		draw shape color:dam_col;
		}
		
			aspect map_deloc {
		draw shape color:deloc_col;
		}
		
	

	aspect map {
	
			draw shape color: color;
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
	float depth<-3#m;
	float water_into <- 0.0;
	float distance_application <- 20 #m;
	float state<-1.0;




	aspect default {
			draw shape color:#aqua border: #black;
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



experiment "Let's go" type: gui
{
	//parameter "File:" var: osmfile <- file<geometry> (osm_file("../includes/map.osm", filtering));
	output
	{
		
		display map_pool type: 3d
		{
			species cell  aspect: map_pool;
			species water;
			species building;
		}
		
		display map_dyke type: 3d
		{
			species cell  aspect: map_dyke;
			species water;
			species building;
		}
		
		display map_dam type: 3d
		{
			species cell  aspect: map_dam;
			species water;
			species building;
		}
		
		display map_deloc type: 3d
		{
			species cell  aspect: map_deloc;
			species water;
			species building;
		}
		
		
		
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

