README.TXT for QME 3.1 preview 2

	QME Version 3.1 preview 2

	This is the LITE version. You may use this for your own purposes and 
	evaluation. Please purchase the FULL version to have unlimited program features.
        If you already have purchased the full version, you can use the patch 
        supplied in the zip file to update your current qme.exe to 3.1 preview 2

	Modeller, Animator, 3D Painter and 2D Texture editor
	Compatible with full version of id software's Quake and Quake 2(TM)

	Windows 95 and Windows NT 4.0

Author : Rene Post
email  : renep@xs4all.nl
www    : http://www.xs4all.nl/~renep/quakeme/
Date   : 18 March 1998

0.  What's new
1.  Disclaimer
2.  Description
3.  Files
4.  Installation Instructions
5.  Important notes on using this version
6.  Known Bugs and Limitiations



0.  What's new

The hot new features in this version include (but are not limited to)

INVERSE KINEMATICS
COLORMAP AND PALETTE EDITOR
FULL SUPPORT FOR QUAKE 2 MODEL FORMAT
FULL SUPPORT FOR HEXEN 2 MISSION PACK MODEL FORMAT 




1. Disclaimer

Quake and id Software Disclaimer
Quake is a registered trademark of id Software. id Software is in no way 
affiliated with, endorses, or frankly cares one red cent about this 
program, any supplemental products, files, information, materials, or 
whatever that happen to accompany this program, are available from the 
makers of this program, or in any way fails to state clearly that it is an 
official id Software product.

To quote id: "THIS PRODUCT REQUIRES THE FULL VERSION OF ID SOFTWARE'S 
QUAKE(TM) TO OPERATE. THIS PRODUCT IS IN NO WAY AFFILIATED AND WILL NOT BE 
SUPPORTED BY ID SOFTWARE, THE CREATORS OF QUAKE(TM)."
Use of this program grants you NO rights whatsoever to any protected 
materials of id Software or any other third party. Namely, if you find a 
source of id texture artwork, skins, or models, you use it at your own 
legal risk.

WE support our product, WE care about our customers, WE will do whatever is 
needed to meet your needs if at all reasonable and possible.



2. Description

QME is a 3D Modeller, Animator, 3D painter and 2D Texture editor for Quake 
MDL files. MDL files contain models of monsters, weapons and other items 
that are used in Quake.

The following very incomplete list of features describes what 
you can do with QME:
- Create new models from prefab components.
- Edit existing vertices and triangles of existing models.
- Paint on the model in 3D and in 2D.
- View and edit 3D texture mapped animations contained in MDL and MD2 files.
- Create new animation frames.
- Import and export textures to a 256 colors windows BMP file. 
- Fit textures around the 3D model by adjusting 2D texture vertices.
- Create a hierarchy of interlinked objects for animation.
- Inverse kinematics with constraints !

You can find MDL files in the PAK0.PAK and PAK1.PAK files that are 
part of Quake. Both files are distributed by id software. To open a 
PAK file use the tools that are freely available on the net.



3. Files

The zip file contains:

qmelite.exe		The lite version.
qmepatch30to31p2.exe	A patch that upgrades your QME 3.0 full version.
humanik.mdo		A demo model showing inverse kinematics.
readme31p2.txt		Your reading it.
xxx colormap.pcx	Several Quake 2 compatible colormaps.



4. Installation Instructions

BEFORE applying this patch or using the lite version, make a 
backup of your current qme installation.

Applying the full version patch...

To apply the patch, place the qmepatch30to31p2.exe in the 
same directory as your original qme.exe. NOTE do NOT overwrite 
your full version qme.exe with the qme.exe in this zip file.
Now start qmepatch30to31p2.exe and let it patch your qme.exe to 
the full version QME 3.1 preview 2

Installing the lite version...

Place the  qme.exe in the same directory as you original qme.exe 
lite release.



5. Important notes on using this version

Something very important has changed in the file format.
In release 3.0 extended information was saved at the 
end of an MDL file. In the 3.1 release this is no longer 
the case.

QME 3.1 has it's own file format ending in the extension MDO. 
Saving a file as MDL will now save it as an ORIGINAL Quake 1 
model. This means that all extended information that is added 
by QME like skin names objects and jointtracks will be LOST.
Therefore never rely on the MDL file as your main model file, 
but ALWAYS work with the model you saved as an MDO file.



6. Known Bugs and Limitations

NOTE THAT THIS IS AN EXPERIMENTAL.VERSION OF QME.
USE THIS PREVIEW RELEASE AT YOUR OWN RISK.

THE DEVELOPER ASSUMES NO LIABILITY FOR ANY FILES 
CREATED, MODIFIED OR DISTRIBUTED UNDER THIS 
AGREEMENT, INCLUDING WITHOUT LIMITATION, 
LIABILITY FOR PATENT OR COPYRIGHT INFRINGEMENT 
AND ANY LOSS OF DATA.

PLEASE BEFORE USING THIS PROGRAM MAKE BACKUPS 
OF ALL YOUR MODEL FILES MADE WITH PREVIOUS 
RELEASES OF QME.

