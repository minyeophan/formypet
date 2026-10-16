package com.formypet.domain.media.storage;

import java.io.IOException;
import org.springframework.stereotype.Component;

@Component
public class MediaImageDimensions {
    public int[] read(byte[] bytes) throws IOException {
            try(var input=javax.imageio.ImageIO.createImageInputStream(new java.io.ByteArrayInputStream(bytes))) {
                var readers=javax.imageio.ImageIO.getImageReaders(input);
                if(readers.hasNext()) {
                    var reader=readers.next();
                    try {
                        reader.setInput(input,true,true);
                        return checkedDimensions(reader.getWidth(0),reader.getHeight(0));
                    } finally { reader.dispose(); }
                }
            }
            int[] webp=webpDimensions(bytes);
            if(webp!=null) return checkedDimensions(webp[0],webp[1]);
            throw new IllegalArgumentException("사진 파일을 읽을 수 없습니다.");
    }

    private int[] checkedDimensions(int width,int height) {
        if(width<=0||height<=0||(long)width*height>50_000_000L) throw new IllegalArgumentException("사진은 5천만 화소 이하로 선택해 주세요.");
        return new int[]{width,height};
    }

    private int[] webpDimensions(byte[] b) {
        if(b.length<30||b[0]!='R'||b[1]!='I'||b[2]!='F'||b[3]!='F'||b[8]!='W'||b[9]!='E'||b[10]!='B'||b[11]!='P') return null;
        for(int i=12;i+8<b.length;){String chunk=new String(b,i,4,java.nio.charset.StandardCharsets.US_ASCII);int size=(b[i+4]&255)|((b[i+5]&255)<<8)|((b[i+6]&255)<<16)|((b[i+7]&255)<<24);int p=i+8;if(size<0||p+size>b.length)return null;
            if("VP8X".equals(chunk)&&size>=10)return new int[]{1+(b[p+4]&255)+((b[p+5]&255)<<8)+((b[p+6]&255)<<16),1+(b[p+7]&255)+((b[p+8]&255)<<8)+((b[p+9]&255)<<16)};
            if("VP8L".equals(chunk)&&size>=5&&(b[p]&255)==0x2f){int bits=(b[p+1]&255)|((b[p+2]&255)<<8)|((b[p+3]&255)<<16)|((b[p+4]&255)<<24);return new int[]{(bits&0x3fff)+1,((bits>>14)&0x3fff)+1};}
            if("VP8 ".equals(chunk)&&size>=10){for(int j=p;j+6<p+size;j++)if((b[j]&255)==0x9d&&(b[j+1]&255)==0x01&&(b[j+2]&255)==0x2a)return new int[]{((b[j+4]&255)<<8|(b[j+3]&255))&0x3fff,((b[j+6]&255)<<8|(b[j+5]&255))&0x3fff};}
            i=p+size+(size&1);
        }return null;
    }
}
