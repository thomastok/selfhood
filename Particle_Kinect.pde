// Data structure
import java.util.Set;

// OSC libraries
import oscP5.*;
import netP5.*;

// Kinect libraries
import KinectPV2.KJoint;
import KinectPV2.*;

// Body of particles to be rendered
HashMap<Integer, ParticleBody> particleBodies; 

// Kinect conatiner
KinectPV2 kinect;

// OSC controller and destiny location
OscP5 oscP5;
NetAddress destinyLocation;

// Max distance between two bodies
float maxDist = dist(0, 0, width, height);

// Inverted kinect
boolean invKinect = false;

// Hands state
ArrayList<Integer> leftState;
ArrayList<Integer> rightState;


// Record variables
boolean isRecording = false;
boolean isPlayingBack = false;


void setup() {
  // Screen size, renderer and frameRate
  //fullScreen(FX2D, SPAN);
  size(1280, 720, FX2D);
  frameRate(30);

  // Kinect setup
  kinect = new KinectPV2(this);
  kinect.enableSkeleton3DMap(true);
  kinect.enableSkeletonColorMap(true);
  kinect.enableColorImg(true);

  kinect.init();
  // Create bodies holder
  particleBodies = new HashMap<Integer, ParticleBody>();

  // Initiate body controller and destiny location
  oscP5 = new OscP5(this, 12000);
  destinyLocation = new NetAddress("143.106.219.176", 12000);

  // Initiate hands state
  try {
    leftState = new ArrayList<Integer>();
    rightState = new ArrayList<Integer>();
    for(int i=0;i<6;i++)
      leftState.add(2);
    for(int i=0;i<6;i++)
      rightState.add(2);
  } catch(NullPointerException ex) {
    println("Exception: " +ex);
  }
  
  
}

void draw() {
  // Clear screen
  background(0);

  // Print FPS
  text("FPS " + round(frameRate), 10, 10 + textAscent());

  // Get bodies from record or kinect
  HashMap<Integer, PVector[]> bodies =  new HashMap<Integer, PVector[]>();
 // Get all joints from the detected bodies
  for (KSkeleton skeleton : kinect.getSkeleton3d())
    if (skeleton.isTracked()){
        if(skeleton.getRightHandState()!=2){
          bodies.put(skeleton.getIndexColor(), 
          mapSkeletonToScreen(skeleton.getJoints()));
        } else {
          bodies.put(color(0,0,0), 
          mapSkeletonToScreen(skeleton.getJoints()));
        }
    }


  Set<Integer> detectedId = bodies.keySet();

  // Update bodies position
  for (Integer id : bodies.keySet()) {
    ParticleBody pBody = particleBodies.getOrDefault(id, null);     

    if (pBody == null) {
      // Create a new particle body
      pBody = new ParticleBody(bodies.get(id), id);
      // Store list
      particleBodies.put(id, pBody);
    } else {
      // Update body's joints
      pBody.update(bodies.get(id));
    }
  }

  ParticleBody[] pBodies = particleBodies.values().toArray(new ParticleBody[0]);

  for (int b = pBodies.length - 1; b >=0; b--) {
    if (detectedId.contains(pBodies[b].bodyColor)) {
      pBodies[b].render(pBodies);
    } else if (pBodies[b].isDead()) {
      particleBodies.remove(b);
    }
  }

  if (detectedId.size() != particleBodies.size()) {
    ArrayList<Integer> deadBodies = new ArrayList<Integer>();

    for (Integer id : particleBodies.keySet())
      if (!deadBodies.contains(id))
        deadBodies.add(id);

    for (Integer id : deadBodies)
      particleBodies.remove(id);
  }

  fill(255);
  text("Body count: " + particleBodies.size(), 10, 20 + textAscent());

  // Send bodies information to PD
  // Send the number of detected bodies
  OscMessage msg = new OscMessage("/people/number");
  msg.add(detectedId.size());
  oscP5.send(msg, destinyLocation);

  // Send coordenates and state of both hands: open(0) and closed(1)
  // PS: if the state is unkonwn, it will interpretate as closed
  for (int body = 0; body < pBodies.length; body++) {
    msg.clear();
    msg.setAddrPattern("/people/position/p" + body);
    ParticleBody particleBody = pBodies[body];
    
    // Mid spine coordinates
    msg.add(map(particleBody.center.x, 0, width, 0, 1));
    msg.add(map(particleBody.center.y, 0, height, 0, 1));
    msg.add(particleBody.center.z);
    try {
      // Coordinates of left hand
      msg.add(map(particleBody.leftHand.x, 0, width, 0, 1));
      msg.add(map(particleBody.leftHand.y, 0, height, 0, 1));
      msg.add(particleBody.leftHand.z);
     
      // Coordinates of right hand
      msg.add(map(particleBody.rightHand.x, 0, width, 0, 1));
      msg.add(map(particleBody.rightHand.y, 0, height, 0, 1));
      msg.add(particleBody.rightHand.z);
      
      // State of left hand: open(2) closed(3)
      if(kinect.getSkeleton3d().get(body).getLeftHandState()==3 && leftState.get(body)==2)
        leftState.set(body,3);
      else if(kinect.getSkeleton3d().get(body).getLeftHandState()==2 && leftState.get(body)==3) 
        leftState.set(body,2);
        
      msg.add(leftState.get(body)-2);
           
      // State of right hand      
      if(kinect.getSkeleton3d().get(body).getRightHandState()==3 && rightState.get(body)==2)
        rightState.set(body,3);
      else if(kinect.getSkeleton3d().get(body).getRightHandState()==2 && rightState.get(body)==3)
        rightState.set(body,2);
        
      msg.add(rightState.get(body)-2);
      
      println("Left hand: "  + "x=" +particleBody.leftHand.x+", y=" + particleBody.leftHand.y+ ", z=" +particleBody.leftHand.z +", state="+(leftState.get(body)==3?"closed":"open"));
      println("Right hand: "  + "x=" +particleBody.rightHand.x+", y=" + particleBody.rightHand.y+ ", z=" +particleBody.rightHand.z +", state="+(rightState.get(body)==3?"closed":"open"));
      
      
      color c1 = color(125, 0, 125);
      color c2 = color(0, 0, 255);
      if(rightState.get(body)==3) {
        fill(c1);
        noStroke();
        ellipse(particleBody.rightHand.x, particleBody.rightHand.y, 80,80);
      }
      if(leftState.get(body)==3) {
        fill(c2);
        noStroke();
        ellipse(particleBody.leftHand.x, particleBody.leftHand.y, 80,80);
      }
  
    } catch(Exception ex){
      println("No body detected");
    }
    oscP5.send(msg, destinyLocation);   
  }
  
  // Send a done signal
  msg.clear();
  msg.setAddrPattern("/people/done");
  msg.add(1);
  oscP5.send(msg, destinyLocation);
}

PVector[] mapSkeletonToScreen(KJoint[] joints) {
  // Create mapped joints array
  PVector[] mappedJoints = new PVector[joints.length];

  if (invKinect) {
    for (int j = 0; j < joints.length; j++) {
      mappedJoints[j] = kinect.MapCameraPointToColorSpace(joints[j].getPosition());
      mappedJoints[j].x = width - mappedJoints[j].x * (float)width / KinectPV2.WIDTHColor;
      mappedJoints[j].y *= (float)height / KinectPV2.HEIGHTColor;
    }
  } else {
    for (int j = 0; j < joints.length; j++) {
      mappedJoints[j] = kinect.MapCameraPointToColorSpace(joints[j].getPosition());
      mappedJoints[j].x *= (float)width / KinectPV2.WIDTHColor;
      mappedJoints[j].y *= (float)height / KinectPV2.HEIGHTColor;
    }
  }
  return mappedJoints;
}

// Particle body
class ParticleBody {
  ParticleSystem[] psJoints;
  PVector center;
  PVector leftHand;
  PVector rightHand;
  int bodyColor;
  Timer addParticleTimer;

  public ParticleBody(PVector[] joints, int bodyColor) {
    // Store body color index
    this.bodyColor = bodyColor;
       
    // Create ps list
    psJoints = new ParticleSystem[joints.length];
    // Create ps joints
    for (int j = 0; j < joints.length; j++)
      psJoints[j] = new ParticleSystem(20, joints[j], bodyColor);
    // Create and start timer
    addParticleTimer = new Timer();
    center = joints[KinectPV2.JointType_SpineMid];
    leftHand = joints[KinectPV2.JointType_HandLeft];
    rightHand = joints[KinectPV2.JointType_HandRight];
  }

  public void update(PVector[] joints) {
    for (int j = 0; j < joints.length; j++)
      // Update ps positions
      psJoints[j].origin = joints[j];
    center = joints[KinectPV2.JointType_SpineMid];
    leftHand = joints[KinectPV2.JointType_HandLeft];
    rightHand = joints[KinectPV2.JointType_HandRight];
  }

  public void render(ParticleBody[] pBodies) {
    // Check if its time to add a new particle to the each ps
    if (addParticleTimer.getTime() > 1) {
      int pColor = bodyColor;
      for (int b = 0; b < pBodies.length; b++) {
        //if(rightState.get(b)==2) bodyColor=0;
        if (pBodies[b].bodyColor == bodyColor)
          continue;
        float dist = dist(pBodies[b].center.x, pBodies[b].center.y, center.x, center.y);
        float choice = random(maxDist); 
        text(choice + " \\ " + dist, 10, 30 + textAscent());
        if (5 * choice > dist) {
          pColor = pBodies[b].bodyColor;
          break;
        }
      }
      for (int j = 0; j < psJoints.length; j++) {
        // Run ps
        psJoints[j].run();
        // Add a new particle to the ps
        psJoints[j].addParticle(1, pColor);
      }
      addParticleTimer.reset();
    } else {
      for (int j = 0; j < psJoints.length; j++) {
        // Run ps
        psJoints[j].run();
      }
    }
  }

  public boolean isDead() {
    for (ParticleSystem ps : psJoints) {
      if (!ps.isDead())
        return false;
    }
    return true;
  }
}

// Particle System
class ParticleSystem {

  ArrayList<Particle> particles;
  PVector origin;
  int psColor;

  ParticleSystem(int num, PVector v, int psColor) {
    this.psColor = psColor;
    particles = new ArrayList<Particle>();
    origin = v.copy();
    addParticle(num, psColor);
  }

  void run() {
    // Cycle through the ArrayList backwards, because we are deleting while iterating
    for (int i = particles.size()-1; i >= 0; i--) {
      Particle p = particles.get(i);
      p.run();
      if (p.isDead()) {
        particles.remove(i);
      }
    }
  }

  void addParticle(int numberParticles, int currentColor) {
    for (int i = 0; i < numberParticles; i++) {
      particles.add(new Particle(origin, currentColor));
    }
  }

  // A method to test if the particle system still has particles
  boolean isDead() {
    return particles.isEmpty();
  }
}

// A simple Particle class
class Particle {
  PVector position;
  PVector velocity;
  PVector acceleration;
  float lifespan;
  int birth;
  int pColor;

  Particle(PVector l, int pColor) {
    acceleration = new PVector(0, 0.1);
    velocity = new PVector(random(-1, 1), random(-2, 0));
    position = l.copy().add(random(-50, 50), random(-50, 50));
    lifespan = 1000.0;
    birth = millis();
    this.pColor = pColor;
  }

  void run() {
    update();
    display();
  }

  // Method to update position
  void update() {
    velocity.add(acceleration);
    position.add(velocity);
  }

  // Method to display
  void display() {
    stroke(255, lifespan);
    fill(pColor, lifespan);
    ellipse(position.x, position.y, 4, 4);
  }

  // Is the particle still useful?
  boolean isDead() {
    return (millis() - birth > lifespan);
  }
}

class Timer {
  int initialTime;

  public Timer() {
    reset();
  }

  public int getTime() {
    return millis() - initialTime;
  }

  public void reset() {
    initialTime = millis();
  }
}

//DRAW BODY
void drawBody(KJoint[] joints) {
  drawBone(joints, KinectPV2.JointType_Head, KinectPV2.JointType_Neck);
  drawBone(joints, KinectPV2.JointType_Neck, KinectPV2.JointType_SpineShoulder);
  drawBone(joints, KinectPV2.JointType_SpineShoulder, KinectPV2.JointType_SpineMid);
  drawBone(joints, KinectPV2.JointType_SpineMid, KinectPV2.JointType_SpineBase);
  drawBone(joints, KinectPV2.JointType_SpineShoulder, KinectPV2.JointType_ShoulderRight);
  drawBone(joints, KinectPV2.JointType_SpineShoulder, KinectPV2.JointType_ShoulderLeft);
  drawBone(joints, KinectPV2.JointType_SpineBase, KinectPV2.JointType_HipRight);
  drawBone(joints, KinectPV2.JointType_SpineBase, KinectPV2.JointType_HipLeft);

  // Right Arm
  drawBone(joints, KinectPV2.JointType_ShoulderRight, KinectPV2.JointType_ElbowRight);
  drawBone(joints, KinectPV2.JointType_ElbowRight, KinectPV2.JointType_WristRight);
  drawBone(joints, KinectPV2.JointType_WristRight, KinectPV2.JointType_HandRight);
  drawBone(joints, KinectPV2.JointType_HandRight, KinectPV2.JointType_HandTipRight);
  drawBone(joints, KinectPV2.JointType_WristRight, KinectPV2.JointType_ThumbRight);

  // Left Arm
  drawBone(joints, KinectPV2.JointType_ShoulderLeft, KinectPV2.JointType_ElbowLeft);
  drawBone(joints, KinectPV2.JointType_ElbowLeft, KinectPV2.JointType_WristLeft);
  drawBone(joints, KinectPV2.JointType_WristLeft, KinectPV2.JointType_HandLeft);
  drawBone(joints, KinectPV2.JointType_HandLeft, KinectPV2.JointType_HandTipLeft);
  drawBone(joints, KinectPV2.JointType_WristLeft, KinectPV2.JointType_ThumbLeft);

  // Right Leg
  drawBone(joints, KinectPV2.JointType_HipRight, KinectPV2.JointType_KneeRight);
  drawBone(joints, KinectPV2.JointType_KneeRight, KinectPV2.JointType_AnkleRight);
  drawBone(joints, KinectPV2.JointType_AnkleRight, KinectPV2.JointType_FootRight);

  // Left Leg
  drawBone(joints, KinectPV2.JointType_HipLeft, KinectPV2.JointType_KneeLeft);
  drawBone(joints, KinectPV2.JointType_KneeLeft, KinectPV2.JointType_AnkleLeft);
  drawBone(joints, KinectPV2.JointType_AnkleLeft, KinectPV2.JointType_FootLeft);

  drawJoint(joints, KinectPV2.JointType_HandTipLeft);
  drawJoint(joints, KinectPV2.JointType_HandTipRight);
  drawJoint(joints, KinectPV2.JointType_FootLeft);
  drawJoint(joints, KinectPV2.JointType_FootRight);

  drawJoint(joints, KinectPV2.JointType_ThumbLeft);
  drawJoint(joints, KinectPV2.JointType_ThumbRight);

  drawJoint(joints, KinectPV2.JointType_Head);
}

//draw joint
void drawJoint(KJoint[] joints, int jointType) {
  pushMatrix();
  translate(joints[jointType].getX(), joints[jointType].getY(), joints[jointType].getZ());
  ellipse(0, 0, 25, 25);
  popMatrix();
}

//draw bone
void drawBone(KJoint[] joints, int jointType1, int jointType2) {
  pushMatrix();
  translate(joints[jointType1].getX(), joints[jointType1].getY(), joints[jointType1].getZ());
  ellipse(0, 0, 25, 25);
  popMatrix();
  line(joints[jointType1].getX(), joints[jointType1].getY(), joints[jointType1].getZ(), joints[jointType2].getX(), joints[jointType2].getY(), joints[jointType2].getZ());
}

//draw hand state
void drawHandState(KJoint joint) {
  noStroke();
  handState(joint.getState());
  pushMatrix();
  translate(joint.getX(), joint.getY(), joint.getZ());
  ellipse(0, 0, 70, 70);
  popMatrix();
}

/*
Different hand state
 KinectPV2.HandState_Open
 KinectPV2.HandState_Closed
 KinectPV2.HandState_Lasso
 KinectPV2.HandState_NotTracked
 */
void handState(int handState) {
  switch(handState) {
  case KinectPV2.HandState_Open:
    fill(0, 255, 0);
    break;
  case KinectPV2.HandState_Closed:
    fill(255, 0, 0);
    break;
  case KinectPV2.HandState_Lasso:
    fill(0, 0, 255);
    break;
  case KinectPV2.HandState_NotTracked:
    fill(255, 255, 255);
    break;
  }
}