interface User {
  id: string;
  name: string;
}


type O = Omit<User, "">

type UT = "a" | "b";

type Exd = Exclude<UT, "">
type Ext = Extract<UT, "">
