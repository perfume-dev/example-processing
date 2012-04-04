package com.rhizomatiks.bvh;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;

import processing.core.PApplet;
import processing.core.PMatrix3D;
import processing.core.PVector;

public class BvhParser {

  private Boolean _motionLoop;
  
  private int _currentFrame = 0;
  
  private List<BvhLine> _lines;
  
  private int _currentLine;
  private BvhBone _currentBone;
  
  private BvhBone _rootBone;
  private List<List<Float>> _frames;
  private int _nbFrames;
  private float _frameTime;
  
  private List<BvhBone> _bones;
  
  public BvhParser()
  {
    _motionLoop = true;
  }

  /**
   * if set to True motion will loop at end
   */
  public Boolean getMotionLoop()
  {
    return _motionLoop;
  }
  
  /**
   * set Loop state
   * @param value
   */
  public void setMotionLoop(Boolean value)
  {
    _motionLoop = value;
  }

  /**
   * to string
   * @return
   */
  public String toStr()
  {
	return _rootBone.structureToString();
  }
  
  /**
   * get frame total
   * @return
   */
  public int getNbFrames()
  {
    return _nbFrames;
  }

  /**
   * get bones list
   * @return
   */
  public List<BvhBone> getBones()
  {
    return _bones;
  }


  /**
   * call before parse BVH
   * 	create array instance
   * 	and setloopstatus true
   */
  public void init()
  {
    _bones = new ArrayList<BvhBone>();
    _motionLoop = true;
  }
  
  /**
   * go to the frame at index
   */
  public void moveFrameTo(int __index)
  {
    if(!_motionLoop)
    {
      if(__index >= _nbFrames)
        _currentFrame = _nbFrames-1;//last frame
    }else{
      while (__index >= _nbFrames)
        __index -= _nbFrames;      
      _currentFrame = __index; //looped frame
    }
    _updateFrame();
  }

  /**
   * go to millisecond of the BVH
   * @param mills millisecond
   * @param loopSec the default loopsec for 
   */
  public void moveMsTo( int mills )
  {
    float frameTime = _frameTime * 1000;
    int curFrame = (int)(mills / frameTime); 
    moveFrameTo( curFrame ); 
  }
  
  /**
   * update bone position and rotation
   */
  public void update()
  {
	  update( getBones().get(0) );
  }
  
  protected void update(BvhBone bone )
  {

	    PMatrix3D m = new PMatrix3D();

	    m.translate(bone.getXposition(), bone.getYposition(), bone.getZposition());
	    m.translate(bone.getOffsetX(), bone.getOffsetY(), bone.getOffsetZ());
	    
	    m.rotateY(PApplet.radians(bone.getYrotation()));
	    m.rotateX(PApplet.radians(bone.getXrotation()));
	    m.rotateZ(PApplet.radians(bone.getZrotation()));
	    
	    bone.global_matrix = m;

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
	      m.translate(bone.getEndOffsetX(), bone.getEndOffsetY(), bone.getEndOffsetZ());
	      m.mult(new PVector(), bone.getAbsEndPosition());
	    }
  }
  
  
  private void _updateFrame()
  {
    if (_currentFrame >= _frames.size()) return;
    List<Float> frame = _frames.get(_currentFrame);
    int count = 0;
    for (float n : frame)
    {
      BvhBone bone = _getBoneInFrameAt(count);
      String prop = _getBonePropInFrameAt(count);
      if(bone != null) {
        Method getterMethod;
        try {
          getterMethod = bone.getClass().getDeclaredMethod("set".concat(prop), new Class[]{float.class});
          getterMethod.invoke(bone, n);
        } catch (SecurityException e) {
          e.printStackTrace();
          System.err.println("ERROR WHILST GETTING FRAME - 1");
        } catch (NoSuchMethodException e) {
          e.printStackTrace();
          System.err.println("ERROR WHILST GETTING FRAME - 2");
        } catch (IllegalArgumentException e) {
          e.printStackTrace();
          System.err.println("ERROR WHILST GETTING FRAME - 3");
        } catch (IllegalAccessException e) {
          e.printStackTrace();
          System.err.println("ERROR WHILST GETTING FRAME - 4");
        } catch (InvocationTargetException e) {
          e.printStackTrace();
          System.err.println("ERROR WHILST GETTING FRAME - 5");
        }
      }
      count++;
    }      
  }    
  
  private String _getBonePropInFrameAt(int n)
  {
    int c = 0;      
    for (BvhBone bone : _bones)
    {
      if (c + bone.getNbChannels() > n)
      {
        n -= c;
        return bone.getChannels().get(n);
      }else{
        c += bone.getNbChannels();  
      }
    }
    return null;
  }
  
  private BvhBone _getBoneInFrameAt( int n)
  {
    int c = 0;      
    for (BvhBone bone : _bones)
    {
      c += bone.getNbChannels();
      if ( c > n )
        return bone;
    }
    return null;
  }    
  
  public void parse(String[] srces)
  {
    String[] linesStr = srces;
    // liste de BvhLines
    _lines = new ArrayList<BvhLine>();
    
    for ( String lineStr : linesStr)
      _lines.add(new BvhLine(lineStr));
      
    _currentLine = 1;
    _rootBone = _parseBone();
    
    // center locs
    //_rootBone.offsetX = _rootBone.offsetY = _rootBone.offsetZ = 0; 
    
    _parseFrames();
  }    
  
  private void _parseFrames()
  {
    int currentLine = _currentLine;
    for (; currentLine < _lines.size(); currentLine++)
      if(_lines.get(currentLine).getLineType() == BvhLine.MOTION) break; 

    if ( _lines.size() > currentLine) 
    {
      currentLine++; //Frames
      _nbFrames = _lines.get(currentLine).getNbFrames();
      currentLine++; //FrameTime
      _frameTime = _lines.get(currentLine).getFrameTime();
      currentLine++;
  
      _frames = new ArrayList<List<Float>>();
      for (; currentLine < _lines.size(); currentLine++)
      {
        _frames.add(_lines.get(currentLine).getFrames());
      }
    }
  }
  
  private BvhBone _parseBone()
  {
    //_currentBone is Parent
    BvhBone bone = new BvhBone( _currentBone );
    
    _bones.add(bone);
    
    bone.setName(  _lines.get(_currentLine)._boneName ); //1
    
    // +2 OFFSET
    _currentLine++; // 2 {
    _currentLine++; // 3 OFFSET
    bone.setOffsetX( _lines.get(_currentLine).getOffsetX() );
    bone.setOffsetY( _lines.get(_currentLine).getOffsetY() );
    bone.setOffsetZ( _lines.get(_currentLine).getOffsetZ() );
      
    // +3 CHANNELS
    _currentLine++;
    bone.setnbChannels( _lines.get(_currentLine).getNbChannels() );
    bone.setChannels( _lines.get(_currentLine).getChannelsProps() );
      
    // +4 JOINT or End Site or }
    _currentLine++;
    while(_currentLine < _lines.size())
    {
      String lineType = _lines.get(_currentLine).getLineType();
      if ( BvhLine.BONE.equals( lineType ) ) //JOINT or ROOT
      {
        BvhBone child = _parseBone(); //generate new BvhBONE
        child.setParent( bone );
        bone.getChildren().add(child);
      }
      else if( BvhLine.END_SITE.equals( lineType ) )
      {
        _currentLine++; // {
        _currentLine++; // OFFSET
        bone.setEndOffsetX( _lines.get(_currentLine).getOffsetX() );
        bone.setEndOffsetY( _lines.get(_currentLine).getOffsetY() );
        bone.setEndOffsetZ( _lines.get(_currentLine).getOffsetZ() );
        _currentLine++; //}
        _currentLine++; //}
        return bone;
      } 
      else if( BvhLine.BRACE_CLOSED.equals( lineType ) )
      {
        return bone; //}
      }
      _currentLine++;
    }
    System.out.println("//Something strage");
    return bone;  
  }    
  
  private class BvhLine
  {
  
    public static final String HIERARCHY = "HIERARCHY";
    public static final String BONE = "BONE";
    public static final String BRACE_OPEN = "BRACE_OPEN";
    public static final String BRACE_CLOSED = "BRACE_CLOSED";
    public static final String OFFSET = "OFFSET";
    public static final String CHANNELS = "CHANNELS";
    public static final String END_SITE = "END_SITE";
    
    public static final String MOTION = "MOTION";
    public static final String FRAMES = "FRAMES";
    public static final String FRAME_TIME = "FRAME_TIME";
    public static final String FRAME = "FRAME";
    
    
    public static final String BONE_TYPE_ROOT = "ROOT";
    public static final String BONE_TYPE_JOINT = "JOINT";
    
    private String _lineStr;
    
    private String _lineType;
    private String _boneType;
    
    private String _boneName;
    private float _offsetX;
    private float _offsetY;
    private float _offsetZ;
    private int _nbChannels;
    private List<String> _channelsProps;
    private int _nbFrames;
    private float _frameTime;
    private List<Float> _frames;
    
    public String toString() 
    {
      return _lineStr;
    }
    
    private void _parse(String __lineStr)
    {
      _lineStr = __lineStr;
      _lineStr = _lineStr.trim();
      _lineStr = _lineStr.replace("\t", "");
      _lineStr = _lineStr.replace("\n", "");
      _lineStr = _lineStr.replace("\r", "");  
      
      String[] words = _lineStr.split(" ");
    
      _lineType = _parseLineType(words);
      
  //    
      if ( HIERARCHY.equals(_lineType) )
      {
        return;
      } else if ( BONE.equals(_lineType) ) {
          _boneType = (words[0] == "ROOT") ? BONE_TYPE_ROOT : BONE_TYPE_JOINT;
          _boneName = words[1];
          return;
      } else if ( OFFSET.equals(_lineType) ) {
          _offsetX = Float.valueOf(words[1]);
          _offsetY = Float.valueOf(words[2]);
          _offsetZ = Float.valueOf(words[3]);
          return;
      } else if ( CHANNELS.equals(_lineType) ) {
          _nbChannels = Integer.valueOf(words[1]);
          _channelsProps = new ArrayList<String>();
          for (int i = 0; i < _nbChannels; i++)
            _channelsProps.add(words[i+2]);
          return;
        
      } else if (FRAMES.equals(_lineType) ) {
          _nbFrames = Integer.valueOf(words[1]);
          return;
      } else if ( FRAME_TIME.equals(_lineType) ) {
          _frameTime = Float.valueOf(words[2]);
          return;
      } else if ( FRAME.equals(_lineType) ) {
          _frames = new ArrayList<Float>();
          for (String word : words) _frames.add(Float.valueOf(word));
          return;
      } else if ( END_SITE.equals(_lineType) ||
            BRACE_OPEN.equals(_lineType) ||
            BRACE_CLOSED.equals(_lineType) ||
            MOTION.equals(_lineType)) {
          return;
      }
    }  
    
    private String _parseLineType( String[] __words) {
      //trace("'" + __words[0] + "' : " + __words[0].length);
      if ( "HIERARCHY".equals(__words[ 0 ] ) )
        return HIERARCHY;
      if ( "ROOT".equals(__words[ 0 ] ) ||
          "JOINT".equals(__words[ 0 ] ) )
        return BONE;
      if ( "{".equals(__words[ 0 ] ) )
        return BRACE_OPEN;
      if ( "}".equals(__words[ 0 ] ) )
        return BRACE_CLOSED;
      if ( "OFFSET".equals(__words[ 0 ] ) )
        return OFFSET;
      if ( "CHANNELS".equals(__words[ 0 ] ) )
        return CHANNELS;
      if ( "End".equals(__words[ 0 ] ) )
        return END_SITE;
      if ( "MOTION".equals(__words[ 0 ] ) )
        return MOTION;
      if ( "Frames:".equals(__words[ 0 ] ) )
        return FRAMES;
      if ( "Frame".equals(__words[ 0 ] ) )
        return FRAME_TIME;
    
      try {
        Float.parseFloat(__words[0]); //check is Parsable
        return FRAME;  
      } catch ( NumberFormatException e) {
        e.printStackTrace();
      }
      return null;
    }
  
    
    public BvhLine(String __lineStr)
    {
      _parse(__lineStr);
    }
    
    public List<Float> getFrames()
    {
      return _frames;
    }
    
    public float getFrameTime()
    {
      return _frameTime;
    }
    
    public int getNbFrames()
    {
      return _nbFrames;
    }
    
    public List<String> getChannelsProps()
    {
      return _channelsProps;
    }
    
    public int getNbChannels()
    {
      return _nbChannels;
    }
    
    public float getOffsetZ()
    {
      return _offsetZ;
    }
    
    public float getOffsetY()
    {
      return _offsetY;
    }
    
    public float getOffsetX()
    {
      return _offsetX;
    }
    
    public String getBoneName()
    {
      return _boneName;
    }
    
    public String getBoneType()
    {
      return _boneType;
    }
    
    public String getLineType()
    {
      return _lineType;
    }
  }
}
