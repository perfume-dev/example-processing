
BvhParser parserA = new BvhParser();
PBvh bvh1, bvh2, bvh3;
public void setup()
{
  size( 1280, 720, P3D );
  background( 0 );
  noStroke();
  frameRate( 30 );
  
  bvh1 = new PBvh( loadStrings( "A_test.bvh" ) );
  bvh2 = new PBvh( loadStrings( "B_test.bvh" ) );
  bvh3 = new PBvh( loadStrings( "C_test.bvh" ) );

  loop();
}

public void draw()
{
  background( 0 );
  camera((float) mouseX, (float) mouseY, 100.f, (float) (width/2.f), (float) (height/2.f), 0.f, 0.f, 1.f, 0.f);
  pushMatrix();
  translate( width/2, height/2 + 100, 0);
  scale(-1, -1, -1);
  bvh1.draw( millis() );
  bvh2.draw( millis() );
  bvh3.draw( millis() );
  popMatrix();
}
