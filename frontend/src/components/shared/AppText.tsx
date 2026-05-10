import React from 'react';
import { Text, TextProps } from 'react-native';

interface AppTextProps extends TextProps {
  bold?: boolean;
}

// 폰트는 app/_layout.tsx에서 한 번만 로드됨. 여기선 family 이름만 사용.
export default function AppText({ bold, style, ...props }: AppTextProps) {
  const fontFamily = bold ? 'NotoSansKR_700Bold' : 'NotoSansKR_400Regular';
  return <Text style={[{ fontFamily }, style]} {...props} />;
}
