public class PBvh
{
  public BvhParser parser;
  private PApplet app;  
  
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

//    pushMatrix();
    update(root);
    draw();
//    popMatrix();
  }

  protected void update(BvhBone bone )
  {
    pushMatrix();

    PMatrix3D m = new PMatrix3D();

    m.translate(bone.getXposition(), bone.getYposition(), bone.getZposition());
    m.translate(bone.getOffsetX(), bone.getOffsetY(), bone.getOffsetZ());
    
    m.rotateY(PApplet.radians(bone.getYrotation()));
    m.rotateX(PApplet.radians(bone.getXrotation()));
    m.rotateZ(PApplet.radians(bone.getZrotation()));
    
    bone.global_matrix = m;
    applyMatrix(m);

    if (bone.getParent() != null && bone.getParent().global_matrix != null)
      m.preApply(bone.getParent().global_matrix);
    m.mult(new PVector(), bone.getAbsPosition());
    
    if (bone.getChildren().size() > 0)
    {
      for (BvhBone child : bone.getChildren())
      {
        update(child);
      }
    }
    else
    {
      translate(bone.getEndOffsetX(), bone.getEndOffsetY(), bone.getEndOffsetZ());
      m.translate(bone.getEndOffsetX(), bone.getEndOffsetY(), bone.getEndOffsetZ());
      m.mult(new PVector(), bone.getAbsEndPosition());
    }

    popMatrix();
  }
  
  protected void draw()
  {
    fill(color(255));
    
    for( BvhBone b : parser.getBones())
    {
      pushMatrix();
      translate( b.absPos.x, b.absPos.y, b.absPos.z);
      sphere(2);
      popMatrix();
      if (!b.hasChildren())
      {
        pushMatrix();
        translate( b.absEndPos.x, b.absEndPos.y, b.absEndPos.z);
        sphere(2);
        popMatrix();
      }
        
    }
  }
}
