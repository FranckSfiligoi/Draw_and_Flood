/**
* Name: OSM file to Agents
* Author:  Patrick Taillandier
* Description: Model which shows how to import a OSM File in GAMA and use it to create Agents. In this model, a filter is done to take only into account the roads 
* and the buildings contained in the file. 
* Tags:  load_file, osm, gis
*/
model simpleOSMLoading


global
{

//map used to filter the object to build from the OSM file according to attributes. for an exhaustive list, see: http://wiki.openstreetmap.org/wiki/Map_Features
	map filtering <- map(["highway"::["primary", "secondary", "tertiary", "motorway", "living_street", "residential", "unclassified"], "waterway"::["stream"],"building"::["yes"]]);
	//OSM file to load
	file<geometry> osmfile <- file<geometry> (osm_file("../includes/map_le_Val2.osm", filtering));

	//compute the size of the environment from the envelope of the OSM file
	geometry shape <- envelope(osmfile);
	file grid_data1 <- grid_file("../gis/RGEALTI_FXX_0945_6265_MNT_LAMB93_IGN69.asc");
	file grid_data2 <- grid_file("../gis/RGEALTI_FXX_0945_6270_MNT_LAMB93_IGN69.asc");
	init
	{
	//possibility to load all of the attibutes of the OSM data: for an exhaustive list, see: http://wiki.openstreetmap.org/wiki/Map_Features
		create osm_agent from: osmfile with: [highway_str::string(read("highway")), building_str::string(read("building")),water_str::string(read("waterway"))];

		//from the created generic agents, creation of the selected agents
		ask osm_agent
		{
			if (length(shape.points) = 1 and highway_str != nil)
			{
				create node_agent with: [shape::shape, type:: highway_str];
			} else
			{
				if (highway_str != nil)
				{
					create road with: [shape::shape, type:: highway_str];
				} else if (building_str != nil)
				{
					create building with: [shape::shape];
				}
			
			
			
			}
			//do the generic agent die
			if (water_str != nil)
				{
					write "opop";
					create water with: [shape::shape];
				}
			do die;
		}
		
	ask cell3 {
		ask cell1 overlapping self {myself.altitude<-grid_value;}
		ask cell2 overlapping self {myself.altitude<-grid_value;}
		write altitude;
	}	
save building to:"../results/buildings_val.shp" format:"shp" attributes: ["ID":: int(self)]; 
save road to:"../results/roads_val.shp" format:"shp" attributes: ["ID":: int(self)]; 
save water to:"../results/waterways_val.shp" format:"shp" attributes: ["ID":: int(self)]; 
save cell3 to:"../results/grid_val.csv" type:"csv" rewrite: true;
	}

}



grid cell1 file: grid_data1;
grid cell2 file: grid_data2;
grid cell3 neighbors: 8 { 
	float altitude;
}

species osm_agent
{
	string highway_str;
	string building_str;
	string water_str;
}

species road
{
	rgb color <- rnd_color(255);
	string type;
	aspect default
	{
		draw shape color: #grey;
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

species node_agent
{
	string type;
	aspect default
	{
		draw square(3) color: # grey;
	}

}

species building
{
	aspect default
	{
		draw shape color: #grey;
	}

}

experiment "Load OSM" type: gui
{
	//parameter "File:" var: osmfile <- file<geometry> (osm_file("../includes/map.osm", filtering));
	output
	{
		display map type: 3d
		{
			species building refresh: false;
			species road refresh: false;
			species node_agent refresh: false;
		}

	}

}

experiment "Load OSM from Internet" type: gui parent: "Load OSM"
{
//	parameter "File:" var: osmfile <- file<geometry> (osm_file("http://download.geofabrik.de/europe/andorra-latest.osm.pbf", filtering));
	
}
