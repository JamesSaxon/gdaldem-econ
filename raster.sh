#!/bin/bash

export GDAL_DATA=/home/jsaxon/anaconda3/share/gdal/

psql census -A -F"," -o acs.csv --pset footer \
    -c "SELECT ST_X(ST_Transform(centroid, 2163)) x, ST_Y(ST_Transform(centroid, 2163)) y, mhi FROM census_tracts_2015 tr JOIN acsprofile5y2015 pr ON tr.state = pr.state AND tr.county = pr.county AND tr.tract = pr.tract WHERE tr.state < 57 AND tr.state NOT IN (2, 15) AND pr.total_pop > 0;"

psql census -t -A -F"," -c "SELECT ST_AsGeoJson(ST_Transform(ST_Union(geom), 2163), 0, 2) FROM states WHERE fips < 57 AND fips NOT IN (2, 15);" -o us.geojson

## To tune the power and N point params, do some loops.
## See below to put these all into a single image matrix...
# for a in $(seq 0.8 0.2 2.0); do 
# for p in $(seq -f %03g 2 2 18) $(seq -w 20 20 200); do

a=0.0
p=004

# gdal_grid -zfield "mhi" -a invdistnn:power=${a}:radius=1000000:max_points=${p}:min_points=2:smoothing=0:nodata=-1 \
#           -outsize 2000 2000 -of GTiff -ot Float65 -l acs acs.vrt acs.tiff --config GDAL_NUM_THREADS ALL_CPUS

gdalwarp -s_srs EPSG:2163 -t_srs EPSG:2163 -crop_to_cutline -cutline us.geojson acs.tiff -overwrite crop.tiff

gdaldem hillshade    crop.tiff            -of PNG hillshade.png
gdaldem color-relief crop.tiff colors.txt -of PNG color.png

composite -compose multiply -blend 60 hillshade.png color.png mhi_terrain.png
convert -bordercolor black -border 100x60 mhi_terrain.png  mhi_terrain_border.png
composite -compose atop -geometry 'x300>+2220+1000' mhi_legend.png mhi_terrain_border.png mhi_terrain_legend.png

cp mhi_terrain_legend.png ~/www/mhi_terrain.png

# montage -label '%f' acs_*[0-9].png \
#         -geometry '500x500>' -bordercolor blue -border 5 -bordercolor white -border 5 -tile 19x -background white \
#         hillshade_params.jpg

