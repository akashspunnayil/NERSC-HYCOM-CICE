add_library(fabm_models_nersc OBJECT
            nersc_model_library.F90
            ecosmo/ecosmo.F90
#            ecosmo/bg.F90
           )

add_dependencies(fabm_models_nersc fabm_base)

#-----------------------------------------------------------------------
# Copyright (C) 2014 - Karsten Bolding and Jorn Bruggeman (BB)         !
#-----------------------------------------------------------------------
