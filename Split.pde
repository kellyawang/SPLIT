  //shapeShifter
  //facetracking via OpenCV

  /* library imports */
  import java.lang.*;
  import processing.video.*;
  import gab.opencv.*;
  import java.awt.*;
  import java.util.Calendar;

/**

  //have a python script run it automatically until it finishes - where to put infinite loop?
  - either in python script or the Processing code
  //restart/reset every 15 min or so - stop memory leaks
  //use threads to calculate where the faces are - save the current and last face locations detected
         - every draw loop?
  //scale once instead of push matrix so many times.
  //draw everything backwards and smaller than actual
  //then scale up
  //
  //make PShape a set of vertices, instead of loading a shape? Will that help?
*/

////////////////////////////////////////////////////////////////////////////////
  /* Modes to control movement analysis behavior */
  int drawMode;
  static int SHP = 2; //SHAPE P_2_3_4_01 shapes
  static int AGENTS = 3; //P_2_2_3 circle

  static boolean SETUP = true;

  /* Parameters for managing capture and video loading */
  Capture video;


  //timer stuff
  //interval in seconds. here 4sec
  int intervalTime = 20;
  int gcTime = 10*60; //10 minutes between each gc
  int secondsSinceStart = 0;
  int delay = 0;
  String startTime = getTimestamp();
  //boolean goVideo = false;


  /* Parameters for drawing agents (P_2_2_3_01) */
  int formResolution = 15;
  float stepSize = 1.0;
  float distortionFactor = 1;
  float initRadius = 150;
  float centerX, centerY;

  boolean filled = false;
  boolean freeze = false;

  //Position target;
  float[] x = new float[formResolution];
  float[] y = new float[formResolution];

  //background
  PImage background;
  Movie bgMovie;
  //variables for SETUP screen
  PFont f;

  /* Parameters for SHP mode */
  float moduleSize = 25;
  PShape lineModule;

  /* OpenCV stuff */
  int counter;
  boolean first = true;
  int nopeople = 0; //for how many frames have we seen no people?
  float curX = 0;
  float curY = 0;
  float newX = 0;
  float newY = 0;
  float dx = 0;
  float dy = 0;
  int n = 4; //how frequently we update bodies
  Position anchor;
  /*
   * n = 2: slowest
   * n = 4: lightning fast
   * n = 10: lightning fast but takes a sec to catch up to actual location
   */

  boolean threadDone = false;
  boolean completed = true;

  OpenCV opencv;
  //humans in the space
  Rectangle[] bodies; //static?
  //and their coordinates
  ArrayList<Position> targets;// = static?

////////////////////////////////////////////////////////////////////////////////
  void setup(){
    //size(displayWidth, displayHeight);
    //size(1280, 720);
    noCursor();
    fullScreen();
    smooth();
    frameRate(25);

    drawMode = SHP;
    targets = new ArrayList<Position>();

    counter = 0;
    delay = 0; //to be used in SETUP delay // 5*60? using millis() method
    bodies = new Rectangle[10];
    anchor = new Position(10, 10);

    targets.add(anchor);
    //left corner:

    //video = new Capture(this, width/2, height/2);
    //video.start();
    //video stuff

    String[] cameras = Capture.list();
    if (cameras.length == 0){
      exit();
    } else {
      video = new Capture(this, width/2, height/2, cameras[0]); //18
      video.start();
    }

    bgMovie = new Movie(this, "perlin_orng.mov");
    bgMovie.loop();

    opencv = new OpenCV(this, width/2, height/2);//might have to scale to half?
    opencv.loadCascade("haarcascade_frontalface_alt.xml");

    lineModule = loadShape("05.svg"); //01, 04, 05
    //background = loadImage("gradient_bronze.jpg");
    //background.resize(width, height);

    //initialize form to be drawn
    //centerX&Y are not actually the center in SHP mode
    centerX = 0;
    centerY = 0;

    //set up components of the SETUP/Welcome page
    f = createFont("Cambria",16,true);
/*
    float angle = radians(360/float(formResolution));
    for (int i=0; i<formResolution; i++){
      x[i] = cos(angle*i) * initRadius;
      y[i] = sin(angle*i) * initRadius;
    }

    stroke(0,50);
    */
    //background(17, 10, 41);
    //background(34, 79, 70);
    //background(46, 51, 65); //dark blue

    //background(209, 77, 0); //orangey
    //set colors for face Circles
    ellipseMode(CENTER);
    //fill(255,102,102,80);
    noStroke();
    image(bgMovie, 0,0);

  }



////////////////////////////////////////////////////////////////////////////////
void draw(){
  //loadPixels();
  //scale(2);

  //video.loadPixels();
  //stop running automatically at 8:30PM
  String timenow = getTimestamp();
  if(timenow.equals("203000")){ //20:30 = 8:30PM
    System.out.println("TIME TO STOP: " + timenow);
    exit();
  }

  //image(bgMovie, 0,0);
  secondsSinceStart = millis() / 1000;

  // stagger the updating of the background
  if (secondsSinceStart % intervalTime == 0){
          //fill(34, 79, 70, 80);
          //fill(46, 51, 65, 80);
          //rect(0,0,width, height);
          tint(255, 80);
          image(bgMovie, 0, 0);
          noTint();
          //targets.clear();
          //println(frameCount);
          //targets.add(new Position(0,0));
   }
   if (secondsSinceStart % gcTime == 0) {
     //println("gc started:");
     System.gc();
   }

  //if SETUP mode, just draw text for now (needs connect to face detection)
  if(SETUP) {
    //timer1Start = millis() / 1000;

    fill(46, 51, 65);

    //shape(s, 0, 0);

    textFont(f, 75);
    //textSize(32);
    fill(255);

    text("FACE ME", width/4, height/4);
    text("Move side to side", width/4, height/4 + 50);
    text("Move UP and DOWN", width/4, height/4 + 150);
    text("BUT", width/4, height/2);
    text("Stay Cautious", width/2, height/2);

    //int c = 0;
    //c = millis() / 1000;
    //if(delay == 0) {
      if(completed) {
        completed = false;
        thread("findFaces");
      }

      if(bodies.length > 0) {
         SETUP = false;
      }
    //}


  } else {

    pushMatrix();
    scale(-2,2); //from this point on everything will be doubled
    translate(-video.width,0);


    //image(video, 0,0);

    //THREAD1
    //detect faces in the video; bodies is updated every frame
    //first is only true for the first draw
    if (first) {
        //start face detection in another thread
        //threadDone = false;
        if(threadDone) {
          threadDone = false;
          thread("findFaces");
          //opencv.loadImage(video);
          //bodies = opencv.detect();

          if(bodies.length > 0) {
              curX = bodies[0].x + bodies[0].width/2;
              curY = bodies[0].x + bodies[0].height/2;
              first = false;
          }
        }

      //for all subsequent draws
      } else {
        //time to update by detecting faces
        if(counter == 0 && threadDone) {
           threadDone = false;
           thread("findFaces");
            //opencv.loadImage(video);
           //bodies = opencv.detect();

           if(bodies.length > 0) {
             //bodies.length > 0
             //set detected face as new position to draw
             newX = bodies[0].x + bodies[0].width/2;
             newY = bodies[0].y + bodies[0].height/2;
             dx = (newX - curX)/n;
             dy = (newY - curY)/n;
             //reset for next update
             curX = newX;
             curY = newY;
             counter = 0;

           }


        //calculate position as fcn of velocity and frames that have passed instead
        //counter < n
        } else {
          newX = curX + counter*dx;
          newY = curY + counter*dy;

      }

        //increment counter to keep track of intervals
        counter = (counter+1) % n;

      }

      // fade every frame so that tracking marks trail off in opacity

      //fill(46, 51, 65, 80);
      //rect(0,0,width, height);


      // Now just draw at newX, newY and use as target for all drawings
      //set colors for face Circles
      //ellipseMode(CENTER);
      //fill(255,102,102,80);
      fill(5, random(90, 202), 102, 50);
      noStroke();

      if(targets.size() > 2){
      //  targets.remove(0);
        targets.remove(1);
      }

      //default target to initialize the ArrayList of targets
      //Position target = new Position(0,0); //will hopefully be overwritten immediately

  //////////comment this out to ignore corner anchor//////////////
      //targets.add(new Position(0,0));
      Position target = new Position(newX, newY);
      targets.add(target);
      //targets.add(new Position(width - 10, height - 10));

      //if(bodies.length > 0) {
        //for (int b = 0; b < bodies.length; b++) {
          //Position target = new Position(bodies[b].x + bodies[b].width/2, bodies[b].y + bodies[b].height/2);
          //target.setX(bodies[0].x + bodies[0].width/2);
          //target.setY(bodies[0].y + bodies[0].height/2);
          float r = random(5, 50);
          ellipse(target.x, target.y, r, r);
          //ellipse(newX, newY, r, r);

          //fill(100);
          //targets.remove(0);
          //targets.add(target);

        //}
      //}

      popMatrix();

      //if (drawMode == AGENTS){
      //   doAgents();
      //}

      if (drawMode == SHP){
        doShape();
      }

    }// else: if(SETUP == false)
} // draw()

////////////////////////////////////////////////////////////////////////////////
void doShape(){
  for (Position p: targets) {

    float d = dist(centerX, centerY, p.x, p.y);


    if (d > stepSize) {
      float angle = atan2(p.y-centerY, p.x-centerX);

      pushMatrix();
      scale(-2,2);
      translate(-video.width, 0);
      translate(p.x, p.y);
      rotate(angle+PI);
      stroke(100);
      strokeWeight(0.25);

      //if(counter == 0){
        shape(lineModule, 0, 0, d, moduleSize);

        //line(p.x, p.y, width/2, height-1);
      //}
      popMatrix();

      centerX = centerX + cos(angle) * stepSize;
      centerY = centerY + sin(angle) * stepSize;

    }
 }
 //counter = (counter+1)%3;

}


void doAgents() {
   //drawing warping circles

    pushMatrix();
    scale(-1,1);
    translate(-video.width, 0);

    Position target = targets.get(0);

    // floating towards target position
    if (target.x != 0 || target.y != 0) {
      centerX += (target.x-centerX) * 0.01;
      centerY += (target.y-centerY) * 0.01;
    }

    // calculate new points
    for (int i=0; i<formResolution; i++){
      x[i] += random(-stepSize,stepSize);
      y[i] += random(-stepSize,stepSize);

    }

    stroke(255);
    strokeWeight(0.75);
    if (filled) fill(random(255));
    else noFill();

    //nonfilled version
    beginShape();
    // start controlpoint
    curveVertex(x[formResolution-1]+centerX, y[formResolution-1]+centerY);

    // only these points are drawn
    for (int i=0; i<formResolution; i++){
      curveVertex(x[i]+centerX, y[i]+centerY);
    }
    curveVertex(x[0]+centerX, y[0]+centerY);

    // end controlpoint
    curveVertex(x[1]+centerX, y[1]+centerY);
    endShape();


    popMatrix();

}



////////////////////////////////////////////////////////////////////////////////


void captureEvent(Capture video){
    //initialize background for first run thru
    video.read();
}


// Called every time a new frame is available to read
void movieEvent(Movie m) {
  m.read();
}

//thread method!
void findFaces() {
  opencv.loadImage(video);
  bodies = opencv.detect();
  threadDone = true;

}


////////////////////////////////////////////////////////////////////////////////
void keyReleased() {
  if (key == 's' || key == 'S') saveFrame(getTimestamp()+"_##.png");

  if (key == DELETE || key == BACKSPACE) {
      //init forms
      centerX = width/2;
      centerY = height/2;
      float angle = radians(360/float(formResolution));
      float radius = initRadius * random(0.5,1.0);
      for (int i=0; i<formResolution; i++){
        x[i] = cos(angle*i) * radius;
        y[i] = sin(angle*i) * radius;
      }
      stroke(0,50);
      background(46, 51, 65);

      //init bodies and targets
      targets.clear();
      targets.add(new Position(0,0));

  }

  if(key == 'a') { drawMode = AGENTS; background(46, 51, 65); }
  if(key == 'b') { drawMode = SHP; background(46, 51, 65); }
  if(key == 't') { SETUP = !SETUP; image(bgMovie, 0,0);}

  //if(key == 'v') goVideo = !goVideo;
  if(key == 'p') { println(targets.size()); println(bodies.length); }

  // load svg for line module
  if(drawMode == SHP){
    if (key=='1') lineModule = loadShape("01.svg");
    if (key=='2') lineModule = loadShape("02.svg");
    if (key=='3') lineModule = loadShape("03.svg");
    if (key=='4') lineModule = loadShape("04.svg");
    if (key=='5') lineModule = loadShape("05.svg");
    if (key=='6') lineModule = loadShape("06.svg");
    if (key=='7') lineModule = loadShape("07.svg");
    if (key=='8') lineModule = loadShape("08.svg");
    if (key=='9') lineModule = loadShape("09.svg");
  }
}

String getTimestamp() {
    Calendar now = Calendar.getInstance();
    return String.format("%1$tH%1$tM%1$tS", now);
  }
