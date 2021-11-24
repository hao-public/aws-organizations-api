export class LambdaCacheController {
  constructor() {
    this.value = null;
    this.timestamp = null;
    this.ttl = 300000; // default 5 minutes
  }

  async getValue() {
    return new Promise((resolve, reject) => {
      try {
        const { timestamp, value, ttl } = this;
        const expiresIn = timestamp + ttl - Date.now();

        resolve(
          value && timestamp && expiresIn > 0
            ? {
                value: JSON.parse(value),
                expiresIn,
              }
            : null
        );
      } catch (e) {
        console.error(e);
        reject(e);
      }
    });
  }

  async setValue(valueToCache, timeToLive) {
    return new Promise((resolve, reject) => {
      try {
        this.value = JSON.stringify(valueToCache);
        this.timestamp = Date.now();
        if (timeToLive) this.ttl = timeToLive;

        resolve(true);
      } catch (e) {
        console.error(e);
        reject(e);
      }
    });
  }
}