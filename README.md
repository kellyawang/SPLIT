Kelly Wang
4/19/2016

shapeShifter (otherwise known as overheadMap) with thread support, as well as optimization for LESS FREQUENT face detection

Current Modes supported:

(key == 's' || key == 'S')		-> save screenshot
(key == DELETE || key == BACKSPACE) 	-> clear screen
(key == 'b') 				-> Shape mode; draw various shapes

if(drawMode == SHP):
if (key=='1') lineModule = loadShape("01.svg");
if (key=='2') lineModule = loadShape("02.svg");
if (key=='3') lineModule = loadShape("03.svg");
if (key=='4') lineModule = loadShape("04.svg");
if (key=='5') lineModule = loadShape("05.svg");
if (key=='6') lineModule = loadShape("06.svg");
if (key=='7') lineModule = loadShape("07.svg");
if (key=='8') lineModule = loadShape("08.svg");
if (key=='9') lineModule = loadShape("09.svg");
