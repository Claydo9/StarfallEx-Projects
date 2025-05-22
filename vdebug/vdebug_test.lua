--@name vdebug_test
--@author Claydo
--@shared
--@include vdebug.txt

require( "vdebug.txt" )

if SERVER then 
    vdebug.initHUD()

    vdebug.wireframeBox( chip():getPos(), Angle( 0, 0, 0 ), Vector( -10, -10, -10 ), Vector( 10, 10, 10 ), true, Color( 255, 0, 0 ) )

    vdebug.line( chip():getPos() + Vector( 10, 0, 20 ), chip():getPos() + Vector( -10, 0, 20 ), true, Color( 0, 255, 0 ) )

    vdebug.box( chip():getPos() + Vector( 0, 0, 40 ), Angle( 0, 0, 0 ), Vector( -10, -10, -10 ), Vector( 10, 10, 10 ), Color( 0, 0, 255 ) )

    vdebug.cross( chip():getPos() + Vector( 0, 0, 60 ), 10, Color( 255, 150, 0 ) )

    vdebug.wireframeSphere( chip():getPos() + Vector( 0, 0, 80 ), 10, 10, 10, true, Color( 0, 100, 150 ) )

    vdebug.sphere( chip():getPos() + Vector( 0, 0, 110 ), 10, 10, 10, true, Color( 150, 0, 150 ) )

    vdebug.text( chip():getPos() + Vector( 0, 0, 130 ), "blehhh", Color( 200, 200, 0 ) )

    vdebug.triangle( chip():getPos() + Vector( -10, -10, 150 ), chip():getPos() + Vector( 10, 10, 150 ), chip():getPos() + Vector( 0, 0, 170 ), Color( 255, 100, 100 ) )

    timer.simple( 0.5, vdebug.popRenderStack )
    timer.simple( 10, vdebug.purgeRenderStack )
end
