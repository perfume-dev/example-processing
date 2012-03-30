

public class PBvh
{
  
  public BvhParser parser;  
  
  public PBvh(String[] data)
  {
    parser = new BvhParser();
    parser.init();
    parser.parse( data );
  }
  
  public void draw( int ms )
  {
    parser.moveMsTo( ms, 3000 );//30-sec loop 

    BvhBone root = parser.getBones().get(0);

    pushMatrix();
    drawBone(root);
    popMatrix();
  }

  protected void drawBone(BvhBone bone)
  {
    pushMatrix();

    PMatrix3D m = new PMatrix3D();

    m.translate(bone.getXposition(), bone.getYposition(), bone.getZposition());
    m.translate(bone.getOffsetX(), bone.getOffsetY(), bone.getOffsetZ());

    m.rotateY(radians(bone.getYrotation()));
    m.rotateX(radians(bone.getXrotation()));
    m.rotateZ(radians(bone.getZrotation()));

    applyMatrix(m);

    sphere( 2 );

    if (bone.getChildren().size() > 0)
    {
      for (BvhBone child : bone.getChildren())
      {
        drawBone(child);
      }
    }
    else
    {
      translate(bone.getEndOffsetX(), bone.getEndOffsetY(), bone.getEndOffsetZ());
      sphere( 2 );
    }

    popMatrix();
  }
}
